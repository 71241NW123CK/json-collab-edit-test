// Brunch automatically concatenates all files in your
// watched paths. Those paths can be configured at
// config.paths.watched in "brunch-config.js".
//
// However, those files will only be executed if
// explicitly imported. The only exception are files
// in vendor, which are never wrapped in imports and
// therefore are always executed.

// Import dependencies
//
// If you no longer want to use a dependency, remember
// to also remove its path from "config.paths.watched".
import "phoenix_html"

// Import local files
//
// Local files can be imported directly using relative
// paths "./socket" or full ones "web/static/js/socket".

// import socket from "./socket"

import Elm from './elm';

const elmTestElmDiv = document.querySelector('#embed_elm_elm_test');
if (elmTestElmDiv) {
  Elm.ElmTest.embed(elmTestElmDiv);
}

const jsonEditorElmDiv = document.querySelector('#embed_elm_json_editor');
if (jsonEditorElmDiv) {
  var userId = '0'
  if (jsonEditorElmDiv.attributes['userid']) {
    userId = jsonEditorElmDiv.attributes['userid'].value;
  }
  var documentId = '0'
  if (jsonEditorElmDiv.attributes['documentid']) {
    documentId = jsonEditorElmDiv.attributes['documentid'].value
  }
  Elm.JsonEditor.embed(jsonEditorElmDiv, {
    userId: userId,
    documentId: documentId
  });
}

// etc. for other modules.
