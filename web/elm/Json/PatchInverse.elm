module Json.PatchInverse exposing (..)

import Json.Decode
import Json.Encode
import Json.Patch
import Json.Pointer
import ElmFpUtils

maybePatchedDocumentWithInversePatch : Json.Decode.Value -> Json.Patch.Patch -> Maybe (Json.Decode.Value, Json.Patch.Patch)
maybePatchedDocumentWithInversePatch document patch =
  case Json.Patch.apply patch document of
    Ok patchedDocument ->
      let
        inverses = accumInverses document patch
        reversedInverses = List.reverse inverses
        inversePatch = List.foldr (++) [] reversedInverses
      in
        Just (patchedDocument, inversePatch)
    _ ->
      Nothing

accumInverses : Json.Decode.Value -> Json.Patch.Patch -> List Json.Patch.Patch
accumInverses currentDocument remainingOperations =
  case remainingOperations of
    [] ->
      []
    remainingOperationsHead :: remainingOperationsTail ->
      let
        remainingOperationsHeadInverse = inverseOperation currentDocument remainingOperationsHead
      in
        case Json.Patch.apply [remainingOperationsHead] currentDocument of
          Ok updatedDocument ->
            remainingOperationsHeadInverse :: accumInverses updatedDocument remainingOperationsTail
          Err _ ->
            []

inverseOperation : Json.Decode.Value -> Json.Patch.Operation -> Json.Patch.Patch
inverseOperation document operation =
  case operation of
    Json.Patch.Add path value ->
      -- To invert an `Add` operation, check to see if there is a value at the
      -- path.  If there is none, then the inverse patch simply `Remove`s the
      -- value at the component path at the original document.  If there is a
      -- value, then check the length of the path.  If the path is empty, then
      -- the inverse patch `Replace`s at the empty path with the original value.
      -- If the path is nonempty, check the value at the init of the path.  If
      -- it is an array, then inverse patch `Remove`s at the component path at
      -- the original document.  Otherwise, the inverse patch `Replace`s at the
      -- path with the original value.
      case Json.Pointer.getAt path document of
        Ok originalValue ->
          case ElmFpUtils.init path of
            Just pathInit ->
              case Json.Pointer.getAt pathInit document of
                Ok pathInitValue ->
                  case Json.Decode.decodeValue (Json.Decode.list Json.Decode.value) pathInitValue of
                    Ok _ ->
                      [Json.Patch.Remove path]
                    _ ->
                      [Json.Patch.Add path originalValue]
                _ ->
                  [] -- This should not happen.
            Nothing ->
              [Json.Patch.Add path originalValue]
        _ ->
          [Json.Patch.Remove (componentJsonPointer path document)]
    Json.Patch.Remove path ->
      case Json.Pointer.getAt path document of
        Ok originalValue ->
          [Json.Patch.Add path originalValue]
        _ -> -- This should not happen
          []
    Json.Patch.Replace path value ->
      case Json.Pointer.getAt path document of
        Ok originalValue ->
          [Json.Patch.Replace path originalValue]
        _ -> -- This should not happen
          []
    Json.Patch.Move from path ->
      case Json.Pointer.getAt path document of
        Ok originalValue ->
          [Json.Patch.Move (componentJsonPointer path document) from, Json.Patch.Add path originalValue]
        _ ->
          [Json.Patch.Move (componentJsonPointer path document) from]
    Json.Patch.Copy from path ->
      case Json.Pointer.getAt path document of
        Ok originalValue ->
          [Json.Patch.Replace path originalValue]
        _ ->
          [Json.Patch.Remove (componentJsonPointer path document)]
    Json.Patch.Test path value ->
      [Json.Patch.Test path value]

componentJsonPointer : Json.Pointer.Pointer -> Json.Decode.Value -> Json.Pointer.Pointer
componentJsonPointer path document =
  case ElmFpUtils.last path of
    Just "-" ->
      case ElmFpUtils.init path of
        Just pathInit ->
          case Json.Pointer.getAt pathInit document of
            Ok valueListValue ->
              case Json.Decode.decodeValue (Json.Decode.list Json.Decode.value) valueListValue of
                Ok valueList ->
                  ElmFpUtils.replaceIndex path ((List.length path) - 1) (toString (List.length valueList))
                _ -> -- this should not happen
                  path
            _ -> -- this should not happen
              path
        _ -> -- this should not happen
          path
    _ -> -- this could happen
      path
