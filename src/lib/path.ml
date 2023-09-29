open! Core

let parse_field =
  let open Angstrom in
  char '.' *> take_till (fun c -> Char.equal '.' c || Char.equal '[' c)
  >>| function
  | "" -> Fn.id
  | key -> fun json ->
    (match json with
    | `Assoc xs ->
      (match List.Assoc.find ~equal:String.equal xs key with
      | None -> failwithf ("Error: an error occured while trying to get a value referenced by a JSON path. \"%s\" is the current JSON context. The \"%s\" key doesn\'t exist.") (Yojson.Safe.to_string json) key ()
      | Some result -> result)
    | _ -> failwithf ("Error: an error occured while trying to get a value referenced by a JSON path. \"%s\" is the current JSON context. The \"%s\" key isn't being applied to an object.") (Yojson.Safe.to_string json) key ()
    )

let parse_int =
  let open Angstrom in
  take_while1 (function '0' .. '9' -> true | _ -> false) >>| int_of_string

let parse_index =
  let open Angstrom in
  (char '[' *> parse_int <* char ']')
  >>| fun index json ->
    match json with
    | `List xs
     |`Tuple xs ->
      (match List.nth xs index with
       | Some result -> result
       | None -> failwithf ("Error: an error occured while trying to get a value referenced by a JSON path. \"%s\" is the current JSON context. The numerical index %d is out of the range of the array.") (Yojson.Safe.to_string json) index ())
    | _ -> failwithf ("Error: an error occured while trying to get a value referenced by a JSON path. \"%s\" is the current JSON context. The array reference is not being applied to an array.") (Yojson.Safe.to_string json) ()

let%expect_test "parse_path" =
  let json = Yojson.Safe.from_string @@ {json|[5, 6, 7]|json} in
  let parser0 = Result.ok_or_failwith @@ Angstrom.parse_string ~consume:All parse_index "[1]" in
  printf !"%{Yojson.Safe.pretty_to_string}" (parser0 json);
  [%expect {| 6 |}]

let parse_path =
  let open Angstrom in
  many ((parse_field <|> parse_index)) >>| fun fs json ->
    List.fold fs ~init:json ~f:(fun acc f -> f acc)

let%expect_test "parse_path" =
  let json = Yojson.Safe.from_string @@ {json|
    {
      "example_field": 123,
      "example_record": {
        "example": 3.14159,
        "example_array": [1, 2, 3, [4, 5]]
      }
    }|json} in
  let parser = Result.ok_or_failwith @@ Angstrom.parse_string ~consume:All parse_path "." in
  printf !"%{Yojson.Safe.pretty_to_string}\n" (parser json);
  let parser0 = Result.ok_or_failwith @@ Angstrom.parse_string ~consume:All parse_path ".example_field" in
  printf !"%{Yojson.Safe.pretty_to_string}\n" (parser0 json);
  let parser1 = Result.ok_or_failwith @@ Angstrom.parse_string ~consume:All parse_path ".example_record" in
  printf !"%{Yojson.Safe.pretty_to_string}\n" (parser1 json);
  let parser2 = Result.ok_or_failwith @@ Angstrom.parse_string ~consume:All parse_path ".example_record.example" in
  printf !"%{Yojson.Safe.pretty_to_string}\n" (parser2 json);
  let parser3 = Result.ok_or_failwith @@ Angstrom.parse_string ~consume:All parse_path ".example_record.example_array[0]" in
  printf !"%{Yojson.Safe.pretty_to_string}\n" (parser3 json);
  let parser4 = Result.ok_or_failwith @@ Angstrom.parse_string ~consume:All parse_path ".example_record.example_array[3][1]" in
  printf !"%{Yojson.Safe.pretty_to_string}\n" (parser4 json);
  [%expect {|
    {
      "example_field": 123,
      "example_record": {
        "example": 3.14159,
        "example_array": [ 1, 2, 3, [ 4, 5 ] ]
      }
    }
    123
    { "example": 3.14159, "example_array": [ 1, 2, 3, [ 4, 5 ] ] }
    3.14159
    1
    5 |}]
