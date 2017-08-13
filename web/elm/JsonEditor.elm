module JsonEditor exposing (main)

import Html exposing (..)
import Html.Attributes exposing (..)
import Html.Events exposing (..)
import Json.Decode
import Json.Encode
import Json.Patch
import Phoenix.Socket
import Phoenix.Channel
import Phoenix.Push
import Task exposing (..)

import ElmConstants
import FileReader exposing (NativeFile, parseSelectedFiles, readAsDataUrl, FileContentDataUrl)
import Json.PatchInverse
import ElmFpUtils

main =
  Html.programWithFlags
    { init = init
    , update = update
    , view = view
    -- todo: subscriptions for channels and shit
    , subscriptions = subscriptions
    }

type alias Flags =
  { userId : String
  , documentId : String
  }

type alias UserDelta =
  { userId : Int
  , patch : Json.Patch.Patch
  , inverse : Json.Patch.Patch
  }

type alias EditorDocument =
  { title : String
  , document : Json.Decode.Value
  , pastUserDeltas : List UserDelta -- THESE ARE STORED IN REVERSE CHRONOLOGICAL ORDER.  MOST RECENT CHANGE IS AT THE HEAD.  I POSIT THIS DESERVES ALLCAPS
  , futureUserDeltas : List UserDelta -- THESE ARE STORED IN CHRONOLOGICAL ORDER.  MOST IMMINENT CHANGE IS AT THE HEAD.  AGAIN, ALLCAPS IS WARRANTED
  , ownerId : Int
  }

type alias Model =
  { userId : Int
  , documentId : Int
  , maybeEditorDocument : Maybe EditorDocument
  , jsonPatchString : String
  , systemError : String
  , phoenixSocket : Phoenix.Socket.Socket Msg
  }

type Msg
  = NoOp
  | JsonPatchStringChanged String
  | Delta
  | Redo
  | Undo
  | JoinChannel
  | PhoenixMsgDelta Json.Encode.Value
  | PhoenixMsgEditorDocument Json.Encode.Value
  | PhoenixMsgRedo Json.Encode.Value
  | PhoenixMsgUndo Json.Encode.Value
  | PhoenixMsg (Phoenix.Socket.Msg Msg)

init : Flags -> (Model, Cmd Msg)
init flags =
  { userId = ElmFpUtils.intFromString flags.userId 0
  , documentId = ElmFpUtils.intFromString flags.documentId 0
  , maybeEditorDocument = Nothing
  , jsonPatchString = ""
  , systemError = ""
  , phoenixSocket = initPhoenixSocket flags
  } ! [joinChannel]

initPhoenixSocket flags
  = (Phoenix.Socket.init ElmConstants.socketUrl)
  |> Phoenix.Socket.withDebug
  |> Phoenix.Socket.on "delta" ("editor:" ++ flags.documentId) PhoenixMsgDelta
  |> Phoenix.Socket.on "editor_document" ("editor:" ++ flags.documentId) PhoenixMsgEditorDocument
  |> Phoenix.Socket.on "redo" ("editor:" ++ flags.documentId) PhoenixMsgRedo
  |> Phoenix.Socket.on "undo" ("editor:" ++ flags.documentId) PhoenixMsgUndo

joinChannel : Cmd Msg
joinChannel =
  Task.succeed JoinChannel
    |> Task.perform identity

update : Msg -> Model -> (Model, Cmd Msg)
update msg model =
  case msg of
    NoOp ->
      model ! []
    JsonPatchStringChanged newJsonPatchString ->
      {model | jsonPatchString = newJsonPatchString} ! []
    Delta ->
      case model.maybeEditorDocument of
        Just editorDocument ->
          case Json.Decode.decodeString Json.Patch.decoder model.jsonPatchString of
            Ok jsonPatch ->
              case Json.PatchInverse.maybePatchedDocumentWithInversePatch editorDocument.document jsonPatch of
                Just (patchedDocument, inverse) ->
                  let
                    payload =
                      (Json.Encode.object [
                        ( "delta"
                        , (Json.Encode.object [
                            ( "user_id"
                            , Json.Encode.int model.userId
                            )
                          , ( "patch"
                            , Json.Patch.encoder jsonPatch
                            )
                          , ( "inverse"
                            , Json.Patch.encoder inverse
                            )
                          ])
                        )
                      ])
                    push_ = Phoenix.Push.init "delta" ("editor:" ++ (toString model.documentId)) |> Phoenix.Push.withPayload payload
                    (phoenixSocket, phoenixCmd) = Phoenix.Socket.push push_ model.phoenixSocket
                  in
                    ({ model | phoenixSocket = phoenixSocket }, Cmd.map PhoenixMsg phoenixCmd)
                Nothing ->
                  model ! []
            _ ->
              model ! []
        _ ->
          model ! []
    Redo ->
      let
        payload =
          (Json.Encode.object [
            ( "redo"
            , (Json.Encode.object [
                ( "user_id"
                , Json.Encode.int model.userId
                )
              ])
            )
          ])
        push_ = Phoenix.Push.init "redo" ("editor:" ++ (toString model.documentId)) |> Phoenix.Push.withPayload payload
        (phoenixSocket, phoenixCmd) = Phoenix.Socket.push push_ model.phoenixSocket
      in
        ({ model | phoenixSocket = phoenixSocket }, Cmd.map PhoenixMsg phoenixCmd)
    Undo ->
      let
        payload =
          (Json.Encode.object [
            ( "undo"
            , (Json.Encode.object [
                ( "user_id"
                , Json.Encode.int model.userId
                )
              ])
            )
          ])
        push_ = Phoenix.Push.init "undo" ("editor:" ++ (toString model.documentId)) |> Phoenix.Push.withPayload payload
        (phoenixSocket, phoenixCmd) = Phoenix.Socket.push push_ model.phoenixSocket
      in
        ({ model | phoenixSocket = phoenixSocket }, Cmd.map PhoenixMsg phoenixCmd)
    JoinChannel ->
      let
        channel = Phoenix.Channel.init ("editor:" ++ (toString model.documentId))
        (phoenixSocket, phoenixCmd) = Phoenix.Socket.join channel model.phoenixSocket
      in
        ({model | phoenixSocket = phoenixSocket}, Cmd.map PhoenixMsg phoenixCmd)
    PhoenixMsgDelta message ->
      case Json.Decode.decodeValue deltaPayloadDecoder message of
        Ok userDelta ->
          case model.maybeEditorDocument of
            Just editorDocument ->
              {model | maybeEditorDocument = Just (changeEditorDocument userDelta editorDocument)} ! []
            _ ->
              model ! []
        _ ->
          model ! []
    PhoenixMsgEditorDocument message ->
      case Json.Decode.decodeValue editorDocumentPayloadDecoder message of
        Ok editorDocument ->
          {model | maybeEditorDocument = Just editorDocument} ! []
        _ ->
          {model | maybeEditorDocument = Nothing} ! []
    PhoenixMsgRedo message ->
      case model.maybeEditorDocument of
        Just editorDocument ->
          {model | maybeEditorDocument = Just (redoEditorDocument editorDocument)} ! []
        _ ->
          model ! []
    PhoenixMsgUndo message ->
      case model.maybeEditorDocument of
        Just editorDocument ->
          {model | maybeEditorDocument = Just (undoEditorDocument editorDocument)} ! []
        _ ->
          model ! []
    PhoenixMsg m ->
      let ( phoenixSocket, phoenixCmd ) = Phoenix.Socket.update m model.phoenixSocket
      in
        ( { model | phoenixSocket = phoenixSocket }, Cmd.map PhoenixMsg phoenixCmd)

view : Model -> Html Msg
view model =
  case model.maybeEditorDocument of
    Just editorDocument ->
      div
        []
        [ text "Herp derp this is Elm durr deee"
        , editorDocumentView editorDocument
        , br [] []
        , textarea [ placeholder "JSON Patch", onInput JsonPatchStringChanged, myStyle ] []
        , br [] []
        , button [ onClick Delta ] [ text "This is a button that does a thing (applies a delta)" ]
        , br [] []
        , div
            []
            ([ button [ onClick Undo ] [ text "UNDO" ] ] ++ (List.map (\userDelta -> text (Json.Encode.encode 4 (userDeltaEncoder userDelta))) editorDocument.pastUserDeltas))
        , br [] []
        , div
            []
            ([ button [ onClick Redo ] [ text "REDO" ] ] ++ (List.map (\userDelta -> text (Json.Encode.encode 4 (userDeltaEncoder userDelta))) editorDocument.futureUserDeltas))
        , br [] []
        -- , button [ onClick Redo ] [ text "REDO" ]
        -- , br [] []
        , text model.jsonPatchString
        , patchStatusView model.jsonPatchString editorDocument
        ]
    Nothing ->
      text "NOTHING TO SEE HERE FOLKS MOVE ALONG"

editorDocumentView editorDocument =
  text ("this is an editor document.  The current value is " ++ (Json.Encode.encode 4 editorDocument.document))

patchStatusView jsonPatchString editorDocument =
  case Json.Decode.decodeString Json.Patch.decoder jsonPatchString of
    Ok jsonPatch ->
      case Json.Patch.apply jsonPatch editorDocument.document of
        Ok patchedDocument ->
          text ("The JSON Patch is valid and applicable.\nThe updated document will be: " ++ (Json.Encode.encode 4 patchedDocument))
        _ ->
          text "The JSON Patch is valid, but not applicable."
    _ ->
      text "The JSON patch is not valid"

myStyle =
  style
    [ ("width", "100%")
    -- , ("height", "40px")
    , ("padding", "10px 0")
    , ("font-size", "2em")
    , ("text-align", "center")
    ]


subscriptions : Model -> Sub Msg
subscriptions model =
    Phoenix.Socket.listen model.phoenixSocket PhoenixMsg

deltaPayloadDecoder =
  Json.Decode.field "delta" userDeltaDecoder

editorDocumentPayloadDecoder =
  Json.Decode.field "editor_document" editorDocumentDecoder

editorDocumentDecoder =
  Json.Decode.map5 EditorDocument
    (Json.Decode.field "title" Json.Decode.string)
    (Json.Decode.field "document" Json.Decode.value)
    (Json.Decode.field "past_user_deltas" (Json.Decode.list userDeltaDecoder))
    (Json.Decode.field "future_user_deltas" (Json.Decode.list userDeltaDecoder))
    (Json.Decode.field "owner_id" Json.Decode.int)

userDeltaDecoder =
  Json.Decode.map3 UserDelta
    (Json.Decode.field "user_id" Json.Decode.int)
    (Json.Decode.field "patch" Json.Patch.decoder)
    (Json.Decode.field "inverse" Json.Patch.decoder)

userDeltaEncoder userDelta =
  Json.Encode.object [
    ( "user_id"
    , Json.Encode.int userDelta.userId
    )
  , ( "patch"
    , Json.Patch.encoder userDelta.patch
    )
  , ( "inverse"
    , Json.Patch.encoder userDelta.inverse
    )
  ]

-- todo: do a "safe" version that returns a Result
changeEditorDocument userDelta editorDocument =
  case Json.Patch.apply userDelta.patch editorDocument.document of
    Ok changedDocument ->
      { editorDocument
      | document = changedDocument
      , pastUserDeltas = userDelta :: editorDocument.pastUserDeltas
      , futureUserDeltas = []
      }
    _ ->
      editorDocument

-- todo: do a "safe" version that returns a Result
redoEditorDocument editorDocument =
  case editorDocument.futureUserDeltas of
    [] ->
      editorDocument
    head :: tail ->
      case Json.Patch.apply head.patch editorDocument.document of
        Ok redoneDocument ->
          { editorDocument
          | document = redoneDocument
          , pastUserDeltas = head :: editorDocument.pastUserDeltas
          , futureUserDeltas = tail
          }
        _ ->
          editorDocument

-- todo: do a "safe" version that returns a Result
undoEditorDocument editorDocument =
  case editorDocument.pastUserDeltas of
    [] ->
      editorDocument
    head :: tail ->
      case Json.Patch.apply head.inverse editorDocument.document of
        Ok undoneDocument ->
          { editorDocument
          | document = undoneDocument
          , pastUserDeltas = tail
          , futureUserDeltas = head :: editorDocument.futureUserDeltas
          }
        _ ->
          editorDocument
