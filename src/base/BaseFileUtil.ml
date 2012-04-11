(******************************************************************************)
(* OASIS: architecture for building OCaml libraries and applications          *)
(*                                                                            *)
(* Copyright (C) 2008-2010, OCamlCore SARL                                    *)
(*                                                                            *)
(* This library is free software; you can redistribute it and/or modify it    *)
(* under the terms of the GNU Lesser General Public License as published by   *)
(* the Free Software Foundation; either version 2.1 of the License, or (at    *)
(* your option) any later version, with the OCaml static compilation          *)
(* exception.                                                                 *)
(*                                                                            *)
(* This library is distributed in the hope that it will be useful, but        *)
(* WITHOUT ANY WARRANTY; without even the implied warranty of MERCHANTABILITY *)
(* or FITNESS FOR A PARTICULAR PURPOSE. See the file COPYING for more         *)
(* details.                                                                   *)
(*                                                                            *)
(* You should have received a copy of the GNU Lesser General Public License   *)
(* along with this library; if not, write to the Free Software Foundation,    *)
(* Inc., 51 Franklin St, Fifth Floor, Boston, MA  02110-1301 USA              *)
(******************************************************************************)

open OASISGettext

let find_file ?(case_sensitive=true) paths exts =

  (* Cardinal product of two list *)
  let ( * ) lst1 lst2 =
    List.flatten
      (List.map
         (fun a ->
            List.map
              (fun b -> a,b)
              lst2)
         lst1)
  in

  let rec combined_paths lst =
    match lst with
      | p1 :: p2 :: tl ->
          let acc =
            (List.map
               (fun (a,b) -> Filename.concat a b)
               (p1 * p2))
          in
            combined_paths (acc :: tl)
      | [e] ->
          e
      | [] ->
          []
  in

  let alternatives =
    List.map
      (fun (p,e) ->
         if String.length e > 0 && e.[0] <> '.' then
           p ^ "." ^ e
         else
           p ^ e)
      ((combined_paths paths) * exts)
  in
    List.find
      (if case_sensitive then
         OASISUtils.file_exists
       else
         Sys.file_exists)
      alternatives

let which prg =
  let path_sep =
    match Sys.os_type with
      | "Win32" ->
          ';'
      | _ ->
          ':'
  in
  let path_lst = OASISString.nsplit (Sys.getenv "PATH") path_sep in
  let exec_ext =
    match Sys.os_type with
      | "Win32" ->
          "" :: (OASISString.nsplit (Sys.getenv "PATHEXT") path_sep)
      | _ ->
          [""]
  in
    find_file ~case_sensitive:false [path_lst; [prg]] exec_ext

(**/**)
let rec fix_dir dn =
  (* Windows hack because Sys.file_exists "src\\" = false when
   * Sys.file_exists "src" = true
   *)
  let ln =
    String.length dn
  in
    if Sys.os_type = "Win32" && ln > 0 && dn.[ln - 1] = '\\' then
      fix_dir (String.sub dn 0 (ln - 1))
    else
      dn

let q = Filename.quote
(**/**)

let cp src tgt =
  BaseExec.run
    (match Sys.os_type with
     | "Win32" -> "copy"
     | _ -> "cp")
    [q src; q tgt]

let mkdir tgt =
  BaseExec.run
    (match Sys.os_type with
       | "Win32" -> "md"
       | _ -> "mkdir")
    [q tgt]

let rec mkdir_parent f tgt =
  let tgt =
    fix_dir tgt
  in
    if OASISUtils.file_exists tgt then
      begin
        if not (Sys.is_directory tgt) then
          OASISUtils.failwithf
            (f_ "Cannot create directory '%s', a file of the same name already \
                 exists")
            tgt
      end
    else
      begin
        mkdir_parent f (Filename.dirname tgt);
        if not (OASISUtils.file_exists tgt) then
          begin
            f tgt;
            mkdir tgt
          end
      end

let rmdir tgt =
  if Sys.readdir tgt = [||] then
    begin
      match Sys.os_type with
        | "Win32" ->
            BaseExec.run "rd" [q tgt]
        | _ ->
            BaseExec.run "rm" ["-r"; q tgt]
    end

let glob fn =
 let basename =
   Filename.basename fn
 in
   if String.length basename >= 2 &&
      basename.[0] = '*' &&
      basename.[1] = '.' then
     begin
       let ext_len =
         (String.length basename) - 2
       in
       let ext =
         String.sub basename 2 ext_len
       in
       let dirname =
         Filename.dirname fn
       in
         Array.fold_left
           (fun acc fn ->
              try
                let fn_ext =
                  String.sub
                    fn
                    ((String.length fn) - ext_len)
                    ext_len
                in
                  if fn_ext = ext then
                    (Filename.concat dirname fn) :: acc
                  else
                    acc
              with Invalid_argument _ ->
                acc)
           []
           (Sys.readdir dirname)
     end
   else
     begin
       if OASISUtils.file_exists fn then
         [fn]
       else
         []
     end
