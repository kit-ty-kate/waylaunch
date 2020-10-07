type dirname = Fpath.t
type filename = Fpath.t
type cmd = string

type 'a io = ('a, Rresult.R.msg) result

module Filenames = Set.Make (String)

let (>>=) = Rresult.(>>=)
let (>>|) = Rresult.(>>|)
let (//) = Fpath.(/)

let path : dirname list =
  Sys.getenv_opt "PATH" |>
  Option.map (String.split_on_char ':') |>
  Option.value ~default:[] |>
  List.map Fpath.v

let history_log : filename io =
  Bos.OS.Dir.user () >>| fun home ->
  home // ".config" // "sway" // "cmd-history"

let history_limit = 50

let history : cmd list =
  Rresult.R.ignore_error ~use:(fun _ -> []) begin
    history_log >>= fun history_log ->
    Bos.OS.File.read_lines history_log
  end

let get_executables (acc : Filenames.t) : Filenames.t =
  List.fold_left (fun acc dir ->
    Bos.OS.Dir.fold_contents ~dotfiles:false ~elements:`Files ~traverse:`None (fun fullname acc ->
      try
        Unix.access (Fpath.to_string fullname) [Unix.X_OK];
        Filenames.add (Fpath.filename fullname) acc
      with
      | Unix.Unix_error _ -> acc
    ) acc dir |>
    Rresult.R.ignore_error ~use:(fun _ -> acc)
  ) acc path

let exec_cmd (execs : Filenames.t) : (cmd * Bos.OS.Cmd.run_status) io =
  let execs =
    execs |>
    Filenames.elements |>
    String.concat "\n"
  in
  Bos.OS.Cmd.in_string execs |>
  Bos.OS.Cmd.run_io Bos.Cmd.(v "env" % "LD_LIBRARY_PATH=/usr/local/lib" % "BEMENU_BACKEND=wayland" % "bemenu" % "-l" % "5") |>
  Bos.OS.Cmd.out_string

let save_cmd (result : (cmd * Bos.OS.Cmd.run_status) io) : unit =
  Rresult.R.ignore_error ~use:(fun _ -> ()) begin
    history_log >>= fun history_log ->
    result >>= function
    | cmd, (_, `Exited 0) ->
        history @ [cmd] |>
        List.filteri (fun i _ -> i <= history_limit) |>
        List.rev |>
        Bos.OS.File.write_lines history_log
    | _ ->
        Ok ()
  end

let () =
  history |>
  Filenames.of_list |>
  get_executables |>
  exec_cmd |>
  save_cmd
