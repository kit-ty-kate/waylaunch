0.3.0 (13/01/2024)
------------------

* Fix history handling.
  It previously threw away new commands after the history file reached 50 lines
* Improve multi-monitors setups by only displaying waylaunch on the first monitor.
  It was previously displayed to the last monitor
* General fixes and improvements of the compilation of the project

0.2.0 (25/10/2020)
------------------

* Get rid of the client code from bemenu and use bemenu's library directly
* Disable use of implicit dependencies

0.1.0 (09/10/2020)
------------------

Initial release.
Just a fork of `bemenu`, binded in OCaml with builtin history and PATH search.
