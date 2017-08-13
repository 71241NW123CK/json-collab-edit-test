defmodule JsonCollabEditTest.EditorChannel do
  use JsonCollabEditTest.Web, :channel

  alias JsonCollabEditTest.EditorDocument
  alias JsonCollabEditTest.UserJsonDelta
  require Logger

  # todo: secure this!!
  def join("editor:"<>documentId, payload, socket) do
    if authorized?(payload) do
      Logger.debug("joining editor:"<>documentId)
      send(self, :after_join)
      {:ok, socket}
    else
      {:error, %{reason: "unauthorized"}}
    end
  end

  def handle_info(:after_join, socket) do
    case socket.topic do
      "editor:"<>documentIdString ->
        case Integer.parse(documentIdString) do
          {documentId, _} ->
            editorDocument = Repo.get!(EditorDocument, documentId)
            pastUserDeltasJson = for pastUserDelta <- editorDocument.past_user_deltas, do: %{"user_id" => pastUserDelta.user_id, "patch" => Poison.decode!(pastUserDelta.patch), "inverse" => Poison.decode!(pastUserDelta.inverse)}
            futureUserDeltasJson = for futureUserDelta <- editorDocument.future_user_deltas, do: %{"user_id" => futureUserDelta.user_id, "patch" => Poison.decode!(futureUserDelta.patch), "inverse" => Poison.decode!(futureUserDelta.inverse)}
            editorDocumentJson = %{
              "title" => editorDocument.title,
              "document" => Poison.decode!(editorDocument.document),
              "past_user_deltas" => pastUserDeltasJson,
              "future_user_deltas" => futureUserDeltasJson,
              "owner_id" => editorDocument.owner_id
            }
            Logger.debug "pushing the editor document"
            # check to see if assigns has a map yet
            socket = assign(socket, "editor_document", editorDocument)
            push socket, "editor_document", %{"editor_document" => editorDocumentJson}
            {:noreply, socket}
          _ ->
            {:error, %{reason: "bad news: something bad happen"}}
        end
      _ ->
        {:error, %{reason: "bad news: something bad happen"}}
    end
  end

  # Channels can be used in a request/response fashion
  # by sending replies to requests from the client
  def handle_in("ping", payload, socket) do
    {:reply, {:ok, payload}, socket}
  end

  # It is also common to receive messages from the client and
  # broadcast to everyone in the current topic (editor:lobby).
  def handle_in("shout", payload, socket) do
    broadcast socket, "shout", payload
    {:noreply, socket}
  end

  # todo: apply the delta to the database
  # todo: consider creating a Phoenix type (embedded Ecto Schema) for JSON Patch?  May be faster?
  def handle_in("delta", %{"delta" => %{"user_id" => user_id, "patch" => patchJson, "inverse" => inverseJson}} = payload, socket) do
    Logger.debug "DELTA"
    Logger.debug "encoding the patch JSON"
    patchString = Poison.encode!(patchJson)
    Logger.debug "encoding the inverse JSON"
    inverseString = Poison.encode!(inverseJson)
    case socket.topic do
      "editor:" <> documentIdString ->
        case Integer.parse(documentIdString) do
          {documentId, _} ->
            # Logger.debug payload
            Logger.debug "Gonna try to get the document"
            editorDocument = Repo.get!(EditorDocument, documentId)
            Logger.debug "Got the document.  Gonna try to decode the document"
            documentJson = Poison.decode!(editorDocument.document)
            Logger.debug "Decoded the document.  Gonna try to apply the patch"
            case Expatch.apply(documentJson, patchJson) do
              {:ok, updatedDocumentJson} ->
                Logger.debug "Successfully updated the document!  Gonna try to persist updated document and new past user deltas"
                newPastUserDeltas = [%UserJsonDelta{user_id: user_id, patch: patchString, inverse: inverseString} | editorDocument.past_user_deltas]
                updatedDocument = Poison.encode!(updatedDocumentJson)
                changeset = EditorDocument.changeset(editorDocument, %{document: updatedDocument})
                changeset = Ecto.Changeset.put_embed(changeset, :past_user_deltas, newPastUserDeltas)
                changeset = Ecto.Changeset.put_embed(changeset, :future_user_deltas, [])
                Logger.debug "Changeset is ready.  Here we go!"
                case Repo.update(changeset) do
                  {:ok, _editor_document} ->
                    Logger.debug "Updated the repo with the updated document.  OK to broadcast delta to everyone"
                    broadcast socket, "delta", payload
                  _ ->
                    Logger.debug "Could not update too bad so sad"
                end
              _ ->
                Logger.debug "Could not update the document!  O noes!"
            end
          _ ->
            Logger.debug "Could not get the document!  O noes!"
        end
      _ ->
        Logger.debug "WTF BBQ"
    end
    {:noreply, socket}
  end

  def handle_in("redo", payload, socket) do
    Logger.debug "REDO"
    case socket.topic do
      "editor:" <> documentIdString ->
        case Integer.parse(documentIdString) do
          {documentId, _} ->
            Logger.debug "Gonna try to get the document"
            editorDocument = Repo.get!(EditorDocument, documentId)
            Logger.debug "Got the document.  Gonna check to see if there is anything to redo"
            case editorDocument.future_user_deltas do
              [head | tail] ->
                Logger.debug "There is a thing to redo.  Gonna try to decode the document."
                documentJson = Poison.decode! editorDocument.document
                Logger.debug "Decoded the document.  Gonna try to decode the patch"
                patchJson = Poison.decode! head.patch
                Logger.debug "Decoded the patch.  Gonna try to apply the patch to the document"
                case Expatch.apply(documentJson, patchJson) do
                  {:ok, updatedDocumentJson} ->
                    Logger.debug "Successfully updated the document!  Gonna try to persist updated document and new past and future user deltas"
                    newPastUserDeltas = [head | editorDocument.past_user_deltas]
                    updatedDocument = Poison.encode! updatedDocumentJson
                    changeset = EditorDocument.changeset(editorDocument, %{document: updatedDocument})
                    changeset = Ecto.Changeset.put_embed(changeset, :past_user_deltas, newPastUserDeltas)
                    changeset = Ecto.Changeset.put_embed(changeset, :future_user_deltas, tail)
                    Logger.debug "Changeset is ready.  Here we go!"
                    case Repo.update(changeset) do
                      {:ok, _editor_document} ->
                        Logger.debug "Updated the repo with the updated document.  OK to broadcast redo to everyone"
                        broadcast socket, "redo", payload
                      _ ->
                        Logger.debug "Could not update too bad so sad"
                    end
                  _ ->
                    Logger.debug "Could not update the document!  O noes!"
                end
              _ ->
                Logger.debug "Nothing to redo!"
            end
          _ ->
            Logger.debug "WTF BBQ"
        end
      _ ->
        Logger.debug "WTF BBQ"
    end
    # broadcast socket, "redo", payload
    {:noreply, socket}
  end

  def handle_in("undo", payload, socket) do
    Logger.debug "UNDO"
    case socket.topic do
      "editor:" <> documentIdString ->
        case Integer.parse(documentIdString) do
          {documentId, _} ->
            Logger.debug "Gonna try to get the document"
            editorDocument = Repo.get!(EditorDocument, documentId)
            Logger.debug "Got the document.  Gonna check to see if there is anything to undo"
            case editorDocument.past_user_deltas do
              [head | tail] ->
                Logger.debug "There is a thing to undo.  Gonna try to decode the document."
                documentJson = Poison.decode! editorDocument.document
                Logger.debug "Decoded the document.  Gonna try to decode the inverse"
                inverseJson = Poison.decode! head.inverse
                Logger.debug "Decoded the inverse.  Gonna try to apply the inverse to the document"
                case Expatch.apply(documentJson, inverseJson) do
                  {:ok, updatedDocumentJson} ->
                    Logger.debug "Successfully updated the document!  Gonna try to persist updated document and new past and future user deltas"
                    newFutureUserDeltas = [head | editorDocument.future_user_deltas]
                    updatedDocument = Poison.encode! updatedDocumentJson
                    changeset = EditorDocument.changeset(editorDocument, %{document: updatedDocument})
                    changeset = Ecto.Changeset.put_embed(changeset, :past_user_deltas, tail)
                    changeset = Ecto.Changeset.put_embed(changeset, :future_user_deltas, newFutureUserDeltas)
                    Logger.debug "Changeset is ready.  Here we go!"
                    case Repo.update(changeset) do
                      {:ok, _editor_document} ->
                        Logger.debug "Updated the repo with the updated document.  OK to broadcast undo to everyone"
                        broadcast socket, "undo", payload
                      _ ->
                        Logger.debug "Could not update too bad so sad"
                    end
                  _ ->
                    Logger.debug "Could not update the document!  O noes!"
                end
              _ ->
                Logger.debug "Nothing to undo!"
            end
          _ ->
            Logger.debug "WTF BBQ"
        end
      _ ->
        Logger.debug "WTF BBQ"
    end
    # broadcast socket, "undo", payload
    {:noreply, socket}
  end

  # Add authorization logic here as required.
  defp authorized?(_payload) do
    true
  end
    #
    # def safePatch(patch, document) do
    #   case document do
    #     nil ->
    #       case patch do
    #         %{"op" => "add", "path" => "", "value" => value} ->
    #           value
    #         _ ->
    #           nil
    #       end
    #     nonNilDocument ->
    #       case Expatch.apply(patch, document)
    #   end
    # end
end
