type dirname = string
type filename = string

module Filenames = Set.Make (String)

let (//) = Filename.concat

let get_path () : dirname list =
  Sys.getenv_opt "PATH" |>
  Option.map (String.split_on_char ':') |>
  Option.value ~default:[]

let get_executables (path : dirname list) : Filenames.t =
  List.fold_left (fun acc dirname ->
    try
      let dir = Unix.opendir dirname in
      let rec loop acc =
        try
          let filename = Unix.readdir dir in
          if filename.[0] = '.' then begin
            loop acc
          end else begin
            let fullname = dirname // filename in
            Unix.access fullname [Unix.X_OK];
            loop (Filenames.add filename acc)
          end
        with
        | Unix.Unix_error _ -> loop acc
        | End_of_file -> acc
      in
      loop acc
    with
    | Unix.Unix_error _ -> acc
  ) Filenames.empty path

let () =
  get_path () |>
  get_executables |>
  Filenames.elements |>
  String.concat "\n" |>
  print_endline
