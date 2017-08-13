module ElmFpUtils exposing (..)

last = List.head << List.reverse

init l =
  case (List.tail << List.reverse) l of
    Just r ->
      Just (List.reverse r)
    _ ->
      Nothing

replaceIndex list index value =
  case list of
    [] ->
      []
    head :: tail ->
      case index of
        0 ->
          value :: tail
        i ->
          if i < 0 then
            []
          else
            head :: replaceIndex tail (i - 1) value

intFromString s d =
  case String.toInt(s) of
    Ok n -> n
    _ -> d
