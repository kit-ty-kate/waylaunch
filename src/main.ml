type dirname = Fpath.t
type filename = Fpath.t
type cmd = string

type 'a io = ('a, Rresult.R.msg) Rresult.result

let (>>=) = Rresult.(>>=)
let (>>|) = Rresult.(>>|)
let (//) = Fpath.(/)

let list_prepend_if_not_duplicate ~eq x l =
  if List.exists (eq x) l then
    l
  else
    x :: l

let path : dirname list =
  Sys.getenv_opt "PATH" |>
  Option.map (String.split_on_char ':') |>
  Option.value ~default:[] |>
  List.map Fpath.v

let history_log : filename io =
  Bos.OS.Dir.user () >>= fun home ->
  let path = home // ".config" // "waylaunch" in
  Bos.OS.Dir.create ~path:true path >>| fun _exists ->
  path // "history"

let history_limit = 50

let history : cmd list =
  Rresult.R.ignore_error ~use:(fun _ -> []) begin
    history_log >>= fun history_log ->
    Bos.OS.File.read_lines history_log
  end

let get_executables (acc : cmd list) : cmd list =
  List.fold_left (fun acc dir ->
    Bos.OS.Dir.fold_contents ~dotfiles:false ~elements:`Files ~traverse:`None (fun fullname acc ->
      try
        Unix.access (Fpath.to_string fullname) [Unix.X_OK];
        list_prepend_if_not_duplicate ~eq:String.equal (Fpath.filename fullname) acc
      with
      | Unix.Unix_error _ -> acc
    ) acc dir |>
    Rresult.R.ignore_error ~use:(fun _ -> acc)
  ) acc path |>
  List.rev

let exec_bemenu (execs : cmd list) : cmd option =
  match Bemenu_bindings.bmenu execs with
  | "" -> None
  | cmd -> Some cmd

let exec (result : cmd option) : cmd io =
  match result with
  | Some cmd ->
      begin match Unix.fork () with
      | 0 -> Unix.execv "/bin/sh" [|"/bin/sh";"-c";cmd|]
      | _ -> Ok cmd
      end
  | _ ->
      Rresult.R.error_msg ""

let save_cmd (cmd : cmd) : unit io =
  history_log >>= fun history_log ->
  let history = (cmd :: history) in
  let history =
    let rec remove_duplicates_and_limit acc limit l =
      match l, limit with
      | [], _ | _, 0 -> acc
      | x::xs, _ ->
          remove_duplicates_and_limit
            (list_prepend_if_not_duplicate ~eq:String.equal x acc)
            (limit - 1)
            xs
    in
    List.rev (remove_duplicates_and_limit [] history_limit history)
  in
  Bos.OS.File.write_lines history_log history

let () =
  Rresult.R.ignore_error ~use:(fun _ -> ()) begin
    history |>
    List.rev |>
    get_executables |>
    exec_bemenu |>
    exec >>=
    save_cmd
  end
