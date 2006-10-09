(* Copyright 2001, 2002 b8_bavard, b8_fee_carabine, INRIA *)
(*
    This file is part of mldonkey.

    mldonkey is free software; you can redistribute it and/or modify
    it under the terms of the GNU General Public License as published by
    the Free Software Foundation; either version 2 of the License, or
    (at your option) any later version.

    mldonkey is distributed in the hope that it will be useful,
    but WITHOUT ANY WARRANTY; without even the implied warranty of
    MERCHANTABILITY or FITNESS FOR A PARTICULAR PURPOSE.  See the
    GNU General Public License for more details.

    You should have received a copy of the GNU General Public License
    along with mldonkey; if not, write to the Free Software
    Foundation, Inc., 59 Temple Place, Suite 330, Boston, MA  02111-1307  USA
*)

open Int64ops
open Printf2
open Md4
open Options
open BasicSocket
open TcpBufferedSocket
open Ip_set

open GuiTypes

open CommonDownloads
open CommonResult
open CommonMessages
open CommonGlobals
open CommonShared
open CommonSearch
open CommonClient
open CommonServer
open CommonNetwork
open CommonTypes
open CommonFile
open CommonComplexOptions
open CommonOptions
open CommonUserDb
open CommonInteractive
open CommonEvent

open DriverInteractive

open Gettext
open Autoconf

let log_prefix = "[dCmd]"

let lprintf_nl fmt =
  lprintf_nl2 log_prefix fmt

let lprintf_n fmt =
  lprintf2 log_prefix fmt

let _s x = _s "DriverCommands" x
let _b x = _b "DriverCommands" x

let to_cancel = ref []

let files_to_cancel o =
  let buf = o.conn_buf in
  Printf.bprintf buf (_b "Files to be cancelled:\n");
  List.iter (fun file ->
      file_print file o
  ) !to_cancel;
  "Type 'confirm yes/no' to cancel them"

let execute_command arg_list output cmd args =
  let buf = output.conn_buf in
  try
    let rec iter list =
      match list with
        [] ->
          Gettext.buftext buf no_such_command cmd
      | (command, _, arg_kind, help) :: tail ->
          if command = cmd then
            Buffer.add_string buf (
              match arg_kind, args with
                Arg_none f, [] -> f output
              | Arg_multiple f, _ -> f args output
              | Arg_one f, [arg] -> f arg  output
              | Arg_two f, [a1;a2] -> f a1 a2 output
              | Arg_three f, [a1;a2;a3] -> f a1 a2 a3 output
              | _ -> bad_number_of_args command help
            )
          else
            iter tail
    in
    iter arg_list
  with Not_found -> ()

let list_options_html o list =
  let buf = o.conn_buf in
  if !!html_mods_use_js_helptext then
    html_mods_table_header buf "upstatsTable" "upstats" [
      ( "0", "srh", "Option name", "Name (Help=mouseOver)" ) ;
      ( "0", "srh", "Option value", "Value (press ENTER to save)" ) ;
      ( "0", "srh", "Option default", "Default" ) ]
  else
    html_mods_table_header buf "voTable" "vo" [
      ( "0", "srh", "Option name", "Name" ) ;
      ( "0", "srh", "Option value", "Value (press ENTER to save)" ) ;
      ( "0", "srh", "Option default", "Default" ) ;
      ( "0", "srh", "Option description", "Help" ) ];

  let counter = ref 0 in

  List.iter (fun o ->
      incr counter;
      if (!counter mod 2 == 0) then Printf.bprintf buf "\\<tr class=\\\"dl-1\\\""
      else Printf.bprintf buf "\\<tr class=\\\"dl-2\\\"";
    
        if !!html_mods_use_js_helptext then
          Printf.bprintf buf " onMouseOver=\\\"mOvr(this);setTimeout('popLayer(\\\\\'%s\\\\\')',%d);setTimeout('hideLayer()',%d);return true;\\\" onMouseOut=\\\"mOut(this);hideLayer();setTimeout('hideLayer()',%d)\\\"\\>"
          (Str.global_replace (Str.regexp "\n") "\\<br\\>" (Http_server.html_real_escaped o.option_help)) !!html_mods_js_tooltips_wait !!html_mods_js_tooltips_timeout !!html_mods_js_tooltips_wait
        else
          Printf.bprintf buf "\\>";

      if String.contains o.option_value '\n' then begin
        Printf.bprintf buf "\\<td class=\\\"sr\\\"\\>
                  \\<a href=\\\"http://mldonkey.sourceforge.net/%s\\\"\\>%s\\</a\\>
                  \\<form action=\\\"submit\\\" target=\\\"$S\\\" onsubmit=\\\"javascript: {setTimeout('window.location.replace(window.location.href)',500);}\\\"\\>
                  \\<input type=hidden name=setoption value=q\\>\\<input type=hidden name=option value=%s\\>\\</td\\>
                  \\<td\\>\\<textarea name=value rows=5 cols=20 wrap=virtual\\>%s\\</textarea\\>
                  \\<input type=submit value=Modify\\>\\</td\\>\\</form\\>
                  \\<td class=\\\"sr\\\"\\>%s\\</td\\>"
                  (String2.upp_initial o.option_name) o.option_name o.option_name o.option_value o.option_default;
                  
          if not !!html_mods_use_js_helptext then
            Printf.bprintf buf "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" (Str.global_replace (Str.regexp "\n") "\\<br\\>" o.option_help);
            
        Printf.bprintf buf "\\</tr\\>"
        end
      
      else begin
        Printf.bprintf buf "\\<td class=\\\"sr\\\"\\>
                  \\<a href=\\\"http://mldonkey.sourceforge.net/%s\\\"\\>%s\\</a\\>\\</td\\>
                  \\<td class=\\\"sr\\\"\\>\\<form action=\\\"submit\\\" target=\\\"$S\\\" onsubmit=\\\"javascript: {setTimeout('window.location.replace(window.location.href)',500);}\\\"\\>
                  \\<input type=hidden name=setoption value=q\\>\\<input type=hidden name=option value=%s\\>"
                  (String2.upp_initial o.option_name) o.option_name o.option_name;

          if o.option_value = "true" || o.option_value = "false" then
            Printf.bprintf buf "\\<select style=\\\"font-family: verdana; font-size: 10px;\\\"
                                name=\\\"value\\\" onchange=\\\"this.form.submit()\\\"\\>
                                \\<option selected\\>%s\\<option\\>%s\\</select\\>"
                                o.option_value (if o.option_value="true" then "false" else "true")
          else
            Printf.bprintf buf "\\<input style=\\\"font-family: verdana; font-size: 10px;\\\"
                                type=text name=value size=20 value=\\\"%s\\\"\\>"
                                o.option_value;

          Printf.bprintf buf "\\</td\\>\\</form\\>\\<td class=\\\"sr\\\"\\>%s\\</td\\>" (shorten o.option_default 40);
          
          if not !!html_mods_use_js_helptext then
            Printf.bprintf buf "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" (Str.global_replace (Str.regexp "\n") "\\<br\\>" o.option_help);
          
          Printf.bprintf buf "\\</tr\\>"
        end;

  )list;
  Printf.bprintf  buf "\\</table\\>\\</div\\>"


let list_options oo list =
  let buf = oo.conn_buf in
  if oo.conn_output = HTML then
    Printf.bprintf  buf "\\<table border=0\\>";
  List.iter (fun o ->
      if String.contains o.option_value '\n' then begin
          if oo.conn_output = HTML then
            Printf.bprintf buf "
                  \\<tr\\>\\<td\\>\\<form action=\\\"submit\\\" $S\\>
                  \\<input type=hidden name=setoption value=q\\>
                  \\<input type=hidden name=option value=%s\\> %s \\</td\\>\\<td\\>
                  \\<textarea name=value rows=10 cols=70 wrap=virtual\\>
                  %s
                  \\</textarea\\>
                  \\<input type=submit value=Modify\\>
                  \\</td\\>\\</tr\\>
                  \\</form\\>
                  " o.option_name o.option_name o.option_value
        end
      else
      if oo.conn_output = HTML then
        Printf.bprintf buf "
              \\<tr\\>\\<td\\>\\<form action=\\\"submit\\\" $S\\>
\\<input type=hidden name=setoption value=q\\>
\\<input type=hidden name=option value=%s\\> %s \\</td\\>\\<td\\>
              \\<input type=text name=value size=40 value=\\\"%s\\\"\\>
\\</td\\>\\</tr\\>
\\</form\\>
              " o.option_name o.option_name o.option_value
      else
        Printf.bprintf buf "$b%s$n = $r%s$n\n" o.option_name o.option_value)
  list;
  if oo.conn_output = HTML then
    Printf.bprintf  buf "\\</table\\>"

let list_calendar o list =
  let buf = o.conn_buf in
  if o.conn_output = HTML then begin
      html_mods_table_header buf "web_infoTable" "vo" [
        ( "0", "srh", "Weekdays", "Weekdays" ) ;
        ( "0", "srh", "Hours", "Hours" ) ;
        ( "0", "srh", "Command", "Command" ) ] ;
      let counter = ref 0 in
      List.iter (fun (wdays, hours, command) ->
          incr counter;
          if (!counter mod 2 == 0) then Printf.bprintf buf "\\<tr class=\\\"dl-1\\\"\\>"
          else Printf.bprintf buf "\\<tr class=\\\"dl-2\\\"\\>";
          let wdays_string = ref "" in
	  let hours_string = ref "" in
	  List.iter (fun day ->
	      if !wdays_string = "" then
	        wdays_string := string_of_int day
	      else
	        wdays_string := Printf.sprintf "%s %s" !wdays_string (string_of_int day)) wdays;
	  List.iter (fun hour ->
	      if !hours_string = "" then
	        hours_string := string_of_int hour
	      else
	        hours_string := Printf.sprintf "%s %s" !hours_string (string_of_int hour)) hours;
          Printf.bprintf buf "
              \\<td title=\\\"%s\\\" class=\\\"sr\\\"\\>%s\\</td\\>
	      \\<td class=\\\"sr\\\"\\>%s\\</td\\>" command !wdays_string !hours_string;
          Printf.bprintf buf "
              \\<td class=\\\"sr\\\"\\>%s\\</td\\>
              \\</tr\\>" command
      ) list;
      Printf.bprintf buf "\\</table\\>\\</div\\>"
    end
  else begin
      Printf.bprintf buf "weekdays / hours / command :\n";
      List.iter (fun (wdays, hours, command) ->
          let wdays_string = ref "" in
	  let hours_string = ref "" in
	  List.iter (fun day ->
	      if !wdays_string = "" then
	        wdays_string := string_of_int day
	      else
	        wdays_string := Printf.sprintf "%s %s" !wdays_string (string_of_int day)) wdays;
	  List.iter (fun hour ->
	      if !hours_string = "" then
	        hours_string := string_of_int hour
	      else
	        hours_string := Printf.sprintf "%s %s" !hours_string (string_of_int hour)) hours;
          Printf.bprintf buf "%s\n%s\n%s\n" !wdays_string !hours_string command
      )list
    end

(*** Note: don't add _s to all command description as it is already done here *)

let register_commands section list =
  register_commands
    (List2.tail_map
      (fun (cmd, action, desc) -> (cmd, section, action, _s desc)) list)


(*************************************************************************)
(*                                                                       *)
(*                         Driver/General                                *)
(*                                                                       *)
(*************************************************************************)


let _ =
  register_commands "Driver/General"
    [

    "dump_heap", Arg_none (fun o ->
(*        Gc.dump_heap (); *)
        "heap dumped"
    ), ":\t\t\t\tdump heap for debug";

    "alias", Arg_multiple ( fun args o ->
        let out = ref "" in
	if List.length args = 0 then begin
	  out := "List of aliases\n\n";
	  List.iter (
	    fun (a,b) ->
	      out := !out ^ a ^ " -> " ^ b ^ "\n"
	  ) !!alias_commands;
	end
	else begin
	  match args with
	      [] | [_] -> out := "Too few arguments"
	    | al::def ->
		(try
		   let old_def = List.assoc al !!alias_commands in
		   out := "removing " ^ al ^ " -> " ^ old_def ^ "\n";
		   alias_commands =:= List.remove_assoc al !!alias_commands;
		 with _ -> ());

		let definition = String.concat " " def in
		alias_commands =:=  (al,definition) :: !!alias_commands;
		out := !out ^ "Alias added";
	end;

	!out
    ), ":\t\t\t\t\t$badd a command alias\n"
       ^"\t\t\t\t\tfor example: \"alias ca cancel all\" makes an alias\n"
       ^"\t\t\t\t\t\"ca\" performing \"cancel all\"\n"
       ^"\t\t\t\t\tto substitute an alias just make a new one\n"
       ^"\t\t\t\t\tfor example: \"alias ca vd\"$n";


    "unalias", Arg_one (
      fun arg o ->
	(try
	   let old_def = List.assoc arg !!alias_commands in
	   alias_commands =:= List.remove_assoc arg !!alias_commands;
	   "removing " ^ arg ^ " -> " ^ old_def
	 with _ -> "Alias not found");

    ), ":\t\t\t\t$bdelete a command alias\n"
       ^"\t\t\t\t\texample: \"unalias ca\"$n";

    "q", Arg_none (fun o ->
        raise CommonTypes.CommandCloseSocket
    ), ":\t\t\t\t\t$bclose telnet$n";

    "kill", Arg_none (fun o ->
        if user2_is_admin o.conn_user.ui_user_name then
	  begin
            CommonInteractive.clean_exit 0;
	    _s "exit"
	  end
        else
          _s "You are not allowed to kill MLDonkey"
        ), ":\t\t\t\t\t$bsave and kill the server$n";

    "urladd", Arg_two (fun kind url o ->
	web_infos_add kind 1 url;
	CommonWeb.load_url true kind url;
        "url added to web_infos. downloading now"
    ), "<kind> <url> :\t\t\tload this file from the web\n"
       ^"\t\t\t\t\tkind is either server.met (if the downloaded file is a server.met)";

    "urlremove", Arg_one (fun url o ->
    	if web_infos_exists url then
	  begin
	    web_infos_remove [("",0,url)];
            "removed URL from web_infos"
	  end
	else
            "URL does not exists in web_infos"
    ), "<url> :\t\t\tremove URL from web_infos";

    "force_web_infos", Arg_none (fun o ->
	CommonWeb.load_web_infos false true;
        "downloading all web_infos URLs"
    ), ":\t\t\tforce downloading all web_infos URLs";

    "recover_temp", Arg_none (fun o ->
        networks_iter (fun r ->
            try
              CommonNetwork.network_recover_temp r
            with _ -> ()
        );
        let buf = o.conn_buf in
        if o.conn_output = HTML then
          html_mods_table_one_row buf "serversTable" "servers" [
            ("", "srh", "Recover temp finished"); ]
        else
          Printf.bprintf buf "Recover temp finished";
        _s ""
    ), ":\t\t\t\trecover lost files from temp directory";

    "vc", Arg_multiple (fun args o ->
        if args = ["all"] then begin
            let buf = o.conn_buf in

            if use_html_mods o then html_mods_table_header buf "vcTable" "vc" ([
                ( "1", "srh ac", "Client number", "Num" ) ;
                ( "0", "srh", "Network", "Network" ) ;
                ( "0", "srh", "IP address", "IP address" ) ;
                ] @ (if !Geoip.active then [( "0", "srh", "Country Code/Name", "CC" )] else []) @ [
                ( "0", "srh", "Client name", "Client name" ) ;
                ( "0", "srh", "Client brand", "CB" ) ;
                ( "0", "srh", "Client release", "CR" ) ;
                ] @
                (if !!emule_mods_count then [( "0", "srh", "eMule MOD", "EM" )] else []));

            let counter = ref 0 in
            let all_clients_list = clients_get_all () in
            List.iter (fun num ->
                let c = client_find num in
                let i = client_info c in
                if use_html_mods o then Printf.bprintf buf "\\<tr class=\\\"%s\\\"
                  title=\\\"Add as friend\\\"
                  onClick=\\\"parent.fstatus.location.href='submit?q=friend_add+%d'\\\"
                  onMouseOver=\\\"mOvr(this);\\\"
                  onMouseOut=\\\"mOut(this);\\\"\\>"
                    (if (!counter mod 2 == 0) then "dl-1" else "dl-2") num;
                    client_print c o;
                    if use_html_mods o then
                    html_mods_td buf ([
                     ("", "sr", i.client_software);
                     ("", "sr", i.client_release);
                     ] @
                     (if !!emule_mods_count then [("", "sr", i.client_emulemod)] else []));
                if use_html_mods o then Printf.bprintf buf "\\</tr\\>"
                else Printf.bprintf buf "\n";
                incr counter;
            ) all_clients_list;
            if use_html_mods o then Printf.bprintf buf "\\</table\\>\\</div\\>";
          end
        else
          List.iter (fun num ->
              let num = int_of_string num in
              let c = client_find num in
              client_print c o;
          ) args;
        ""
    ), "<num> :\t\t\t\tview client (use arg 'all' for all clients)";

    "version", Arg_none (fun o ->
	print_command_result o o.conn_buf (CommonGlobals.version ());
        ""
    ), ":\t\t\t\tprint mldonkey version";

    "uptime", Arg_none (fun o ->
	print_command_result o o.conn_buf (log_time () ^ "- up " ^
	  Date.time_to_string (last_time () - start_time) "verbose");
        ""
    ), ":\t\t\t\tcore uptime";

    "sysinfo", Arg_none (fun o ->
	let buf = o.conn_buf in
        ignore(buildinfo (o.conn_output = HTML) buf);
        if o.conn_output = HTML then Printf.bprintf buf "\\<P\\>";
        ignore(runinfo (o.conn_output = HTML) buf o);
        if o.conn_output = HTML then Printf.bprintf buf "\\<P\\>";
        ignore(portinfo (o.conn_output = HTML) buf);
        if o.conn_output = HTML then Printf.bprintf buf "\\<P\\>";
        ignore(diskinfo (o.conn_output = HTML) buf);
        ""
    ), ":\t\t\t\tprint mldonkey core build, runtime and disk information";

    "buildinfo", Arg_none (fun o ->
	let buf = o.conn_buf in
        ignore(buildinfo (o.conn_output = HTML) buf);
        ""
    ), ":\t\t\t\tprint mldonkey core build information";

    "runinfo", Arg_none (fun o ->
	let buf = o.conn_buf in
        ignore(runinfo (o.conn_output = HTML) buf o);
        ""
    ), ":\t\t\t\tprint mldonkey runtime information";

    "portinfo", Arg_none (fun o ->
	let buf = o.conn_buf in
        ignore(portinfo (o.conn_output = HTML) buf);
        ""
    ), ":\t\t\t\tprint mldonkey port usage information";

    "diskinfo", Arg_none (fun o ->
	let buf = o.conn_buf in
        ignore(diskinfo (o.conn_output = HTML) buf);
        ""
    ), ":\t\t\t\tprint mldonkey disk information";

    "activity", Arg_one (fun arg o ->
        let arg = int_of_string arg in
        let buf = o.conn_buf in
        let activity_begin = last_time () - arg * 60 in
        Fifo.iter (fun a ->
            if a.activity_begin > activity_begin then begin
                Printf.bprintf buf "%s: activity =\n" (BasicSocket.string_of_date a.activity_begin);
                Printf.bprintf buf "   servers: edonkey %03d/%03d\n"
                  a.activity_server_edonkey_successful_connections
                  a.activity_server_edonkey_connections;
                Printf.bprintf buf "   clients: overnet %03d/%03d edonkey %03d/%03d\n"
                  a.activity_client_overnet_successful_connections
                  a.activity_client_overnet_connections
                  a.activity_client_edonkey_successful_connections
                  a.activity_client_edonkey_connections;
                Printf.bprintf buf "   indirect: overnet %03d edonkey %03d\n"
                  a.activity_client_overnet_indirect_connections
                  a.activity_client_edonkey_indirect_connections;
              end
        ) activities;
        ""
    ), "<minutes> :\t\t\tprint activity in the last <minutes> minutes";

    "message_log", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let counter = ref 0 in

        (match args with
            [arg] ->
              let refresh_delay = int_of_string arg in
              if use_html_mods o && refresh_delay > 1 then
                Printf.bprintf buf "\\<meta http-equiv=\\\"refresh\\\" content=\\\"%d\\\"\\>"
                  refresh_delay;
          | _ -> ());

(* rely on GC? *)

        while (Fifo.length chat_message_fifo) > !!html_mods_max_messages  do
          ignore (Fifo.take chat_message_fifo)
        done;

        if use_html_mods o then Printf.bprintf buf "\\<div class=\\\"messages\\\"\\>";

        last_message_log := last_time();
        Printf.bprintf buf "%d logged messages\n" (Fifo.length chat_message_fifo);

        if Fifo.length chat_message_fifo > 0 then
          begin

            if use_html_mods o then
              html_mods_table_header buf "serversTable" "servers" [
                ( "0", "srh", "Timestamp", "Time" ) ;
                ( "0", "srh", "IP address", "IP address" ) ;
                ( "1", "srh", "Client number", "Num" ) ;
                ( "0", "srh", "Client name", "Client name" ) ;
                ( "0", "srh", "Message text", "Message" ) ] ;

            Fifo.iter (fun (t,i,num,n,s) ->
                if use_html_mods o then begin
                    Printf.bprintf buf "\\<tr class=\\\"%s\\\"\\>"
                      (if (!counter mod 2 == 0) then "dl-1" else "dl-2");
                    html_mods_td buf [
                      ("", "sr", Date.simple (BasicSocket.date_of_int t));
                      ("", "sr",  i);
                      ("", "sr", Printf.sprintf "%d" num);
                      ("", "sr", n);
                      ("", "srw", (String.escaped s)) ];
                    Printf.bprintf buf "\\</tr\\>"
                  end
                else
                  Printf.bprintf buf "\n%s [client #%d] %s(%s): %s\n"
                    (Date.simple (BasicSocket.date_of_int t)) num n i s;
                incr counter;
            ) chat_message_fifo;
            if use_html_mods o then Printf.bprintf buf
                "\\</table\\>\\</div\\>\\</div\\>";

          end;

        ""
    ), ":\t\t\t\tmessage_log [refresh delay in seconds]";

    "message", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          n :: msglist ->
            let msg = List.fold_left (fun a1 a2 ->
                  a1 ^ a2 ^ " "
              ) "" msglist in
            let cnum = int_of_string n in
            client_say (client_find cnum) msg;
	    log_chat_message "localhost" 0 !!global_login msg;
            Printf.sprintf "Sending msg to client #%d: %s" cnum msg;
        | _ ->
            if use_html_mods o then begin

                Printf.bprintf buf "\\<script type=\\\"text/javascript\\\"\\>
\\<!--
function submitMessageForm() {
var formID = document.getElementById(\\\"msgForm\\\")
var regExp = new RegExp (' ', 'gi') ;
var msgTextOut = formID.msgText.value.replace(regExp, '+');
parent.fstatus.location.href='submit?q=message+'+formID.clientNum.value+\\\"+\\\"+msgTextOut;
formID.msgText.value=\\\"\\\";
}
//--\\>
\\</script\\>";

                Printf.bprintf buf "\\<iframe id=\\\"msgWindow\\\" name=\\\"msgWindow\\\" height=\\\"80%%\\\"
            width=\\\"100%%\\\" scrolling=yes src=\\\"submit?q=message_log+20\\\"\\>\\</iframe\\>";

                Printf.bprintf buf "\\<form style=\\\"margin: 0px;\\\" name=\\\"msgForm\\\" id=\\\"msgForm\\\" action=\\\"javascript:submitMessageForm();\\\"\\>";
                Printf.bprintf buf "\\<table width=100%% cellspacing=0 cellpadding=0 border=0\\>\\<tr\\>\\<td\\>";
                Printf.bprintf buf "\\<select style=\\\"font-family: verdana;
            font-size: 12px; width: 150px;\\\" id=\\\"clientNum\\\" name=\\\"clientNum\\\" \\>";

                Printf.bprintf buf "\\<option value=\\\"1\\\"\\>Client/Friend list\n";

                let found_nums = ref [] in
                let fifo_list = Fifo.to_list chat_message_fifo in
                let fifo_list = List.rev fifo_list in
                let found_select = ref 0 in
                List.iter (fun (t,i,num,n,s) ->
                    if not (List.mem num !found_nums) then begin

                        found_nums := num :: !found_nums;
                        Printf.bprintf buf "\\<option value=\\\"%d\\\" %s\\>%d:%s\n"
                          num
                          (if !found_select=0 then "selected" else "";)
                        num (try
                            let c = client_find num in
                            let g = client_info c in
                            g.client_name
                          with _ -> "unknown/expired");
                        found_select := 1;
                      end
                ) fifo_list;
                List.iter (fun c ->
                    let g = client_info c in
                    if not (List.mem g.client_num !found_nums) then begin
                        found_nums := g.client_num :: !found_nums;
                        Printf.bprintf buf "\\<option value=\\\"%d\\\"\\>%d:%s\n"
                          g.client_num g.client_num g.client_name;
                      end
                ) !!friends;

                Printf.bprintf buf "\\</select\\>\\</td\\>";
                Printf.bprintf buf "\\<td width=100%%\\>\\<input style=\\\"width: 99%%; font-family: verdana; font-size: 12px;\\\"
                type=text id=\\\"msgText\\\" name=\\\"msgText\\\" size=50 \\>\\</td\\>";
                Printf.bprintf buf "\\<td\\>\\<input style=\\\"font-family: verdana;
            font-size: 12px;\\\" type=submit value=\\\"Send\\\"\\>\\</td\\>\\</form\\>";
                Printf.bprintf buf "\\<form style=\\\"margin: 0px;\\\" id=\\\"refresh\\\" name=\\\"refresh\\\"
            action=\\\"javascript:msgWindow.location.reload();\\\"\\>
            \\<td\\>\\<input style=\\\"font-family: verdana; font-size: 12px;\\\" type=submit
            Value=\\\"Refresh\\\"\\>\\</td\\>\\</form\\>\\</tr\\>\\</table\\>";
                ""
              end
            else
              _s "Usage: message <client num> <msg>\n";

    ), "<client num> <msg> :\t\tsend a message to a client";

    "calendar_add", Arg_two (fun hour action o ->
        let buf = o.conn_buf in
        calendar =:= ([0;1;2;3;4;5;6], [int_of_string hour], action)
        :: !!calendar;
        if use_html_mods o then
          html_mods_table_one_row buf "serversTable" "servers" [
            ("", "srh", "action added"); ]
        else
          Printf.bprintf buf "action added";
        _s ""
    ), "<hour> \"<command>\" :\tadd a command to be executed every day";

    "vcal", Arg_none (fun o ->
        let buf = o.conn_buf in
        if use_html_mods o then begin
            Printf.bprintf buf "\\<div class=\\\"vo\\\"\\>
                \\<table class=main cellspacing=0 cellpadding=0\\>\\<tr\\>\\<td\\>";
	    if !!calendar = [] then
              html_mods_table_one_row buf "serversTable" "servers" [
                ("", "srh", "no jobs defined"); ]
	    else
              list_calendar o !!calendar;
            Printf.bprintf buf "\\</td\\>\\</tr\\>\\</table\\>\\</div\\>\\<P\\>";
	    print_option_help o calendar
          end
        else
	  if List.length !!calendar = 0 then
	    Printf.bprintf buf "no jobs defined"
	  else
            list_calendar o !!calendar;
        ""
    ), ":\t\t\t\t\tprint calendar";

    ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Servers                                *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Servers"
    [

    "vm", Arg_none (fun o ->
        let buf = o.conn_buf in
        if use_html_mods o then Printf.bprintf buf
            "\\<div class=\\\"servers\\\"\\>\\<table align=center border=0 cellspacing=0 cellpadding=0\\>\\<tr\\>\\<td\\>";
        CommonInteractive.print_connected_servers o;
        if use_html_mods o then Printf.bprintf buf "\\</td\\>\\</tr\\>\\</table\\>\\</div\\>";
        ""), ":\t\t\t\t\t$blist connected servers$n";

    "vma", Arg_none (fun o ->
        let buf = o.conn_buf in
        html_mods_cntr_init ();
        let nb_servers = ref 0 in
        if use_html_mods o then server_print_html_header buf "";
        Intmap.iter (fun _ s ->
            try
              server_print s o;
              incr nb_servers;
            with e ->
                lprintf "Exception %s in server_print\n"
                  (Printexc2.to_string e);
        ) !!servers;
        if use_html_mods o then begin
            Printf.bprintf buf "\\</table\\>\\</div\\>";
            html_mods_table_one_row buf "serversTable" "servers" [
              ("", "srh", Printf.sprintf "Servers: %d known" !nb_servers); ]
          end
        else
          Printf.bprintf buf "Servers: %d known\n" !nb_servers;
        if Autoconf.donkey = "yes" && not !!enable_servers then
          begin
            if use_html_mods o then begin
                Printf.bprintf buf "\\<div class=servers\\>";
                html_mods_table_one_row buf "upstatsTable" "upstats" [
                  ("", "srh", ("You disabled server usage, therefore you are not" ^
                    " able to connect ED2K servers. " ^
                    "To use servers again 'set enable_servers true'")); ]
              end
            else
              Buffer.add_string buf ("You disabled server usage, therefore you are not" ^
                " able to connect ED2K servers.\n" ^
                "To use servers again 'set enable_servers true'\n");
            if use_html_mods o then Printf.bprintf buf "\\</div\\>"
          end;
    ""), ":\t\t\t\t\tlist all known servers";

    "rem", Arg_multiple (fun args o ->
	let counter = ref 0 in
	match args with
	  ["all"] ->
            Intmap.iter ( fun _ s ->
              server_remove s;
	      incr counter
            ) !!servers;
            Printf.sprintf (_b "Removed all %d servers") !counter
	| ["blocked"] ->
            Intmap.iter ( fun _ s ->
              if server_blocked s then
		begin
		  server_remove s;
		  incr counter
		end
            ) !!servers;
            Printf.sprintf (_b "Removed %d blocked servers") !counter
	| ["disc"] ->
            Intmap.iter (fun _ s ->
	      match server_state s with
		NotConnected _ ->
		  begin
		    server_remove s;
		    incr counter
		  end
	      | _ -> ()) !!servers;
            Printf.sprintf (_b "Removed %d disconnected servers") !counter
	| _ ->
            List.iter (fun num ->
                let num = int_of_string num in
                let s = server_find num in
                server_remove s
            ) args;
            Printf.sprintf (_b"%d servers removed") (List.length args)
    ), "<server numbers|all|blocked|disc> :\t\t\tremove server(s) ('all'/'blocked'/'disc' = all/IP blocked/disconnected servers)";

    "server_banner", Arg_one (fun num o ->
        let num = int_of_string num in
        let s = server_find num in
        (match server_state s with
            NotConnected _ -> ()
          | _ ->   server_banner s o);
        ""
    ), "<num> :\t\t\tprint banner of connected server <num>";

    "server_shares", Arg_one (fun num o ->
	if user2_is_admin o.conn_user.ui_user_name then
        let s = server_find (int_of_string num) in
        (match server_state s with
           Connected _ -> let list = ref [] in
	    List.iter (fun f -> 
	      match file_shared f with
		None -> ()
	      | Some sh -> list := (as_shared_impl sh) :: !list)
	      (server_published s);
	    print_upstats o !list (Some s)
	  | _ -> ()
	)
	else print_command_result o o.conn_buf "You are not allowed to use this command";
	_s ""
    ), "<num> :\t\t\tshow list of files published on server <num>";

    "c", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          [] ->
            networks_iter network_connect_servers;
            if o.conn_output = HTML then
              html_mods_table_one_row buf "serversTable" "servers" [
                ("", "srh", "Connecting more servers"); ]
            else
              Printf.bprintf buf "connecting more servers";
            _s
        ""
        | _ ->
            List.iter (fun num ->
                let num = int_of_string num in
                let s = server_find num in
                server_connect s
            ) args;
            if o.conn_output = HTML then
              html_mods_table_one_row buf "serversTable" "servers" [
                ("", "srh", "Connecting more servers"); ]
            else
              Printf.bprintf buf "connecting server";
            _s
        ""
    ), "[<num>] :\t\t\t\tconnect to more servers (or to server <num>)";

    "x", Arg_one (fun num o ->
        let num = int_of_string num in
        let s = server_find num in
        (match server_state s with
            NotConnected _ -> ()
          | _ ->   server_disconnect s);
        ""
    ), "<num> :\t\t\t\tdisconnect from server";

  ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Friends                                *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Friends"
    [

    "vfr", Arg_none (fun o ->
        List.iter (fun c ->
            client_print c o) !!friends;
        ""
    ), ":\t\t\t\t\tview friends";

    "gfr", Arg_one (fun num o ->
        let num = int_of_string num in
        let c = client_find num in
        client_browse c true;
        _s "client browse"
    ), "<client num> :\t\t\task friend files";

    "friend_add", Arg_one (fun num o ->
        let num = int_of_string num in
        let c = client_find num in
        friend_add c;
        _s "Added friend"
    ), "<client num> :\t\tadd client <client num> to friends";

    "friend_remove", Arg_multiple (fun args o ->
        if args = ["all"] then begin
            List.iter (fun c ->
                friend_remove c
            ) !!friends;
            _s "Removed all friends"
          end else begin
            List.iter (fun num ->
                let num = int_of_string num in
                let c = client_find num in
                friend_remove c;
            ) args;
            Printf.sprintf (_b "%d friends removed") (List.length args)
          end
    ), "<client numbers> :\tremove friend (use arg 'all' for all friends)";

    "friends", Arg_none (fun o ->
        let buf = o.conn_buf in

        if use_html_mods o then begin
            Printf.bprintf buf "\\<div class=\\\"friends\\\"\\>\\<table class=main cellspacing=0 cellpadding=0\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap class=fbig\\>\\<a onclick=\\\"javascript:window.location.reload()\\\"\\>Refresh\\</a\\> \\</td\\>
\\<td nowrap class=fbig\\>\\<a onclick=\\\"javascript:
                  { parent.fstatus.location.href='submit?q=friend_remove+all';
                    setTimeout('window.location.reload()',1000);
                    }\\\"\\>Remove All\\</a\\>
\\</td\\>
\\<td nowrap class=\\\"fbig pr\\\"\\>\\<a onclick=\\\"javascript: {
                   var getip = prompt('Friend IP [port] ie: 192.168.0.1 4662','192.168.0.1 4662')
                   var reg = new RegExp (' ', 'gi') ;
                   var outstr = getip.replace(reg, '+');
                   parent.fstatus.location.href='submit?q=afr+' + outstr;
                    setTimeout('window.location.reload()',1000);
                    }\\\"\\>Add by IP\\</a\\>
\\</td\\>
\\</tr\\>\\</table\\>
\\</td\\>\\</tr\\>
\\<tr\\>\\<td\\>";
            html_mods_table_header buf "friendsTable" "friends" [
              ( "1", "srh", "Client number", "Num" ) ;
              ( "0", "srh", "Remove", "Remove" ) ;
              ( "0", "srh", "Network", "Network" ) ;
              ( "0", "srh", "Name", "Name" ) ;
              ( "0", "srh", "State", "State" ) ] ;
          end;
        let counter = ref 0 in
        List.iter (fun c ->
            let i = client_info c in
            let n = network_find_by_num i.client_network in
            if use_html_mods o then
              begin

                Printf.bprintf buf "\\<tr class=\\\"%s\\\"
                onMouseOver=\\\"mOvr(this);\\\"
                onMouseOut=\\\"mOut(this);\\\"\\>"
                  (if (!counter mod 2 == 0) then "dl-1" else "dl-2");

                incr counter;
                Printf.bprintf buf "
			\\<td title=\\\"Client number\\\"
			onClick=\\\"location.href='submit?q=files+%d'\\\"
			class=\\\"srb\\\"\\>%d\\</td\\>
			\\<td title=\\\"Remove friend\\\"
			onClick=\\\"parent.fstatus.location.href='submit?q=friend_remove+%d'\\\"
			class=\\\"srb\\\"\\>Remove\\</td\\>
			\\<td title=\\\"Network\\\" class=\\\"sr\\\"\\>%s\\</td\\>
			\\<td title=\\\"Name (click to view files)\\\"
			onClick=\\\"location.href='submit?q=files+%d'\\\"
			class=\\\"sr\\\"\\>%s\\</td\\>
	 		\\<td title=\\\"Click to view files\\\"
            onClick=\\\"location.href='submit?q=files+%d'\\\"
            class=\\\"sr\\\"\\>%s\\</td\\>
			\\</tr\\>"
                  i.client_num
                  i.client_num
                  i.client_num
                  n.network_name
                  i.client_num
                  i.client_name
                  i.client_num

                  (let rs = client_files c in
                  if (List.length rs) > 0 then Printf.sprintf "%d Files Listed" (List.length rs)
                  else string_of_connection_state (client_state c) )

              end

            else
              Printf.bprintf buf "[%s %d] %s" n.network_name
                i.client_num i.client_name
        ) !!friends;

        if use_html_mods o then
          Printf.bprintf buf " \\</table\\>\\</td\\>\\<tr\\>\\</table\\>\\</div\\>";

        ""
    ), ":\t\t\t\tdisplay all friends";

    "files", Arg_one (fun arg o ->
        let buf = o.conn_buf in
        let n = int_of_string arg in
        List.iter (fun c ->
            if client_num c = n then begin
                let rs = client_files c in

                let rs = List2.tail_map (fun (s, rs) ->
                      let r = IndexedResults.get_result rs in
                      rs, r, 1
                  ) rs in
                o.conn_user.ui_last_results <- [];
                DriverInteractive.print_results 0 buf o rs;

                ()
              end
        ) !!friends;
        ""), "<client num> :\t\t\tprint files from friend <client num>";


  ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Network                                *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Network"
    [

    "nu", Arg_one (fun num o ->
        let num = int_of_string num in

        if num > 0 then (* we want to disable upload for a short time *)
          let num = mini !CommonUploads.upload_credit num in
          CommonUploads.has_upload := !CommonUploads.has_upload + num;
          CommonUploads.upload_credit := !CommonUploads.upload_credit - num;
          Printf.sprintf
            "upload disabled for %d minutes (remaining credits %d)"
            !CommonUploads.has_upload !CommonUploads.upload_credit
        else

        if num < 0 && !CommonUploads.has_upload > 0 then
(* we want to restart upload probably *)
          let num = - num in
          let num = mini num !CommonUploads.has_upload in
          CommonUploads.has_upload := !CommonUploads.has_upload - num;
          CommonUploads.upload_credit := !CommonUploads.upload_credit + num;
          Printf.sprintf
            "upload disabled for %d minutes (remaining credits %d)"
            !CommonUploads.has_upload !CommonUploads.upload_credit

        else ""
    ), "<m> :\t\t\t\tdisable upload during <m> minutes (multiple of 5)";

    "bw_stats", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        if use_html_mods o then
          begin
            display_bw_stats := true;
            let refresh_delay = ref !!html_mods_bw_refresh_delay in
            if args <> [] then begin
                let newrd = int_of_string (List.hd args) in
                if newrd > 1 then refresh_delay := newrd;
              end;

            let dlkbs =
              (( (float_of_int !udp_download_rate) +. (float_of_int !control_download_rate)) /. 1024.0) in
            let ulkbs =
              (( (float_of_int !udp_upload_rate) +. (float_of_int !control_upload_rate)) /. 1024.0) in

            Printf.bprintf buf "\\</head\\>\\<body\\>\\<div class=\\\"bw_stats\\\"\\>";
            Printf.bprintf buf "\\<table class=\\\"bw_stats\\\" cellspacing=0 cellpadding=0\\>\\<tr\\>";
            Printf.bprintf buf "\\<td\\>\\<table border=0 cellspacing=0 cellpadding=0\\>\\<tr\\>";

            html_mods_td buf [
              ("Download KB/s (UDP|TCP)", "bu bbig bbig1 bb4", Printf.sprintf "Down: %.1f KB/s (%d|%d)"
                  dlkbs !udp_download_rate !control_download_rate);
              ("Upload KB/s (UDP|TCP)", "bu bbig bbig1 bb4", Printf.sprintf "Up: %.1f KB/s (%d|%d)"
                  ulkbs !udp_upload_rate !control_upload_rate);
              ("Total shared files/bytes", "bu bbig bbig1 bb4", Printf.sprintf "Shared(%d): %s"
                !nshared_files (size_of_int64 !nshared_bytes));
              ("Total uploaded bytes", "bu bbig bbig1 bb3", Printf.sprintf "Uploaded: %s"
                (size_of_int64 !upload_counter) ) ];


            Printf.bprintf buf "\\</tr\\>\\</table\\>\\</td\\>\\</tr\\>\\</table\\>\\</div\\>";

            Printf.bprintf buf "\\<script type=\\\"text/javascript\\\"\\>window.parent.document.title='(D:%.1f) (U:%.1f) | %s | %s'\\</script\\>"
              dlkbs ulkbs o.conn_user.ui_user_name (CommonGlobals.version ())
          end
        else
          DriverInteractive.print_bw_stats buf;
        ""
    ), ":\t\t\t\tprint current bandwidth stats";

    "stats", Arg_none (fun o ->
        let buf = o.conn_buf in
        CommonInteractive.network_display_stats buf o;
        if use_html_mods o then
          print_gdstats buf o;
      _s ""), ":\t\t\t\t\tdisplay transfer statistics";

    "gdstats", Arg_none (fun o ->
        let buf = o.conn_buf in
	if Autoconf.has_gd then
          if use_html_mods o then
            print_gdstats buf o
          else
            Printf.bprintf buf "Only available on HTML interface"
	else
	  Printf.bprintf buf "Gd support was not compiled";
      _s ""), ":\t\t\t\tdisplay graphical transfer statistics";

    "gdremove", Arg_none (fun o ->
        let buf = o.conn_buf in
	if Autoconf.has_gd then
	  begin
	    DriverGraphics.G.really_remove_files ();
	    Printf.bprintf buf "Gd files were removed"
	  end
	else
	  Printf.bprintf buf "Gd support was not compiled";
      _s ""), ":\t\t\t\tremove graphical transfer statistics files";

    "!", Arg_multiple (fun arg o ->
        if !!allow_any_command then
          match arg with
            c :: tail ->
              let args = String2.unsplit tail ' ' in
              let cmd = try List.assoc c !!allowed_commands with Not_found -> c in
              let tmp = Filename.temp_file "com" ".out" in
              let ret = Sys.command (Printf.sprintf "%s %s > %s"
                    cmd args tmp) in
              let output = File.to_string tmp in
              Sys.remove tmp;
              Printf.sprintf (_b "%s\n---------------- Exited with code %d") output ret
          | _ -> _s "no command given"
        else
        match arg with
          [arg] ->
	    (try
            let cmd = List.assoc arg !!allowed_commands in
            let tmp = Filename.temp_file "com" ".out" in
            let ret = Sys.command (Printf.sprintf "%s > %s"
                  cmd tmp) in
            let output = File.to_string tmp in
            Sys.remove tmp;
            Printf.sprintf (_b "%s\n---------------- Exited with code %d") output ret
	    with e -> "For arbitrary commands, you must set 'allowed_any_command'")
        | [] ->
            _s "no command given"
        | _ -> "For arbitrary commands, you must set 'allowed_any_command'"
    ), "<cmd> :\t\t\t\tstart command <cmd>\n\t\t\t\t\tmust be allowed in 'allowed_commands' option or by 'allow_any_command' if arguments";


  ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Networks                               *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Networks"
    [

    "networks", Arg_none (fun o ->
        let buf = o.conn_buf in
        print_network_modules buf o;
        ""
    ) , ":\t\t\t\tprint all networks";

    "enable", Arg_one (fun num o ->
        let n = network_find_by_num (int_of_string num) in
        network_enable n;
        _s "network enabled"
    ) , "<num> :\t\t\t\tenable a particular network";

    "disable", Arg_one (fun num o ->
        let n = network_find_by_num (int_of_string num) in
        network_disable n;
        _s "network disabled"
    ) , "<num> :\t\t\t\tdisable a particular network";

    "porttest", Arg_none (fun o ->
        let buf = o.conn_buf in
	networks_iter (fun n -> 
	  match network_porttest_result n with
	    PorttestNotAvailable -> ()
	  | _ -> network_porttest_start n);
        if o.conn_output = HTML then
          Printf.bprintf buf "Click this \\<a href=\\\"porttest\\\"\\>link\\</a\\> to see results"
        else
          Printf.bprintf buf "Test started, you need a HTML browser to display results";
        ""
    ) , ":\t\t\t\tstart network porttest";

    ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Searches                               *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Searches"
    [

    "forget", Arg_multiple (fun args o ->
        let user = o.conn_user in
        begin
          match args with
            ["all"] ->
              List.iter (fun s ->
                  CommonSearch.search_forget user (CommonSearch.search_find s.search_num);
              ) user.ui_user_searches
          | [] ->
              begin
                match user.ui_user_searches with
                  [] -> ()
                | s :: _ ->
                    CommonSearch.search_forget user
                      (CommonSearch.search_find s.search_num);
              end

          | _ ->
              List.iter (fun arg ->
                  let num = int_of_string arg in
                  CommonSearch.search_forget user (CommonSearch.search_find num)
              ) args;
        end;
        ""
    ), "<num1> <num2> ... :\t\tforget searches <num1> <num2> ...";

    "vr", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let user = o.conn_user in
        match args with
          num :: _ ->
            List.iter (fun num ->
                let num = int_of_string num in
                let s = search_find num in
                DriverInteractive.print_search buf s o) args;
            ""
        | [] ->
            begin
              match user.ui_user_searches with
                [] ->
                  if o.conn_output = HTML then
                    html_mods_table_one_row buf "searchTable" "search" [
                      ("", "srh", "No search to print"); ]
                  else
                    Printf.bprintf buf "No search to print";
            ""
              | s :: _ ->
                  DriverInteractive.print_search buf s o;
                  ""
            end;
    ), "[<num>] :\t\t\t\t$bview results of a search$n";

    "s", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let user = o.conn_user in
        let query, net = CommonSearch.search_of_args args in
        ignore (CommonInteractive.start_search user
            (let module G = GuiTypes in
            { G.search_num = 0;
              G.search_query = query;
              G.search_max_hits = 10000;
              G.search_type = RemoteSearch;
              G.search_network = net;
            }) buf);
        ""
    ), "<query> :\t\t\t\t$bsearch for files on all networks$n\n\n\tWith special args:\n\t-network <netname>\n\t-minsize <size>\n\t-maxsize <size>\n\t-media <Video|Audio|...>\n\t-Video\n\t-Audio\n\t-format <format>\n\t-title <word in title>\n\t-album <word in album>\n\t-artist <word in artist>\n\t-field <field> <fieldvalue>\n\t-not <word>\n\t-and <word>\n\t-or <word>\n";

    "ls", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let user = o.conn_user in
        let query, net = CommonSearch.search_of_args args in
        ignore (CommonInteractive.start_search user
            (let module G = GuiTypes in
            { G.search_num = 0;
              G.search_query = query;
              G.search_max_hits = 10000;
              G.search_type = LocalSearch;
              G.search_network = net;
            }) buf);
        ""
    ), "<query> :\t\t\t\tsearch for files locally\n\n\tWith special args:\n\t-network <netname>\n\t-minsize <size>\n\t-maxsize <size>\n\t-media <Video|Audio|...>\n\t-Video\n\t-Audio\n\t-format <format>\n\t-title <word in title>\n\t-album <word in album>\n\t-artist <word in artist>\n\t-field <field> <fieldvalue>\n\t-not <word>\n\t-and <word>\n\t-or <word>\n";

    "vs", Arg_none (fun o ->
        let buf = o.conn_buf in
        let user = o.conn_user in
        let num_searches = List.length user.ui_user_searches in
        if num_searches < 1 then
          if o.conn_output = HTML then
            html_mods_table_one_row buf "searchTable" "search" [
              ("", "srh", "No search yet"); ]
          else
            Printf.bprintf buf "No search yet"
        else begin
            if o.conn_output = HTML then
              Printf.bprintf  buf "Searching %d queries\n" (
                List.length user.ui_user_searches);
            List.iter (fun s ->
                Printf.bprintf buf "%s[%-5d]%s %s %s (found %d)\n"
                  (if o.conn_output = HTML then
                    Printf.sprintf "\\<a href=\\\"submit\\?q=forget\\+%d\\\" target=fstatus\\>[Forget]\\</a\\> \\<a href=\\\"submit\\?q=vr\\+%d\\\"\\>" s.search_num s.search_num
                  else "")
                s.search_num
                  s.search_string
                  (if o.conn_output = HTML then "\\</a\\>" else "")
                (if s.search_waiting = 0 then _s "done" else
                    string_of_int s.search_waiting)
                s.search_nresults
            ) (Sort.list (fun f1 f2 -> f1.search_num < f2.search_num)
            user.ui_user_searches)
          end;
        ""
    ), ":\t\t\t\t\tview all queries";

    "view_custom_queries", Arg_none (fun o ->
        let buf = o.conn_buf in
        if o.conn_output <> HTML then
          Printf.bprintf buf "%d custom queries defined\n"
            (List.length (customized_queries ()));
        let custom_commands = ref [] in
	List.iter (fun (name, q) ->
            if o.conn_output = HTML then
              begin
                if use_html_mods o then
                  custom_commands := !custom_commands @ [ ( "bu bbig",
                  name,
                  Printf.sprintf "top.output.location.href='submit\\?custom=%s'" (Url.encode name),
                  name ) ; ]
                else
                  Printf.bprintf buf
                    "\\<a href=\\\"submit\\?custom=%s\\\" $O\\> %s \\</a\\>\n"
                    (Url.encode name) name;
              end
            else

              Printf.bprintf buf "[%s]\n" name
        ) (customized_queries ());

        if use_html_mods o then
          html_mods_commands buf "commandsTable" "commands" (!custom_commands @ [
            ("bu bbig", "Visit FileHeaven",
             "top.output.location.href='http://www.fileheaven.org/'", "FileHeaven");
            ("bu bbig", "Visit FileDonkey",
             "top.output.location.href='http://www.filedonkey.com/'", "FileDonkey");
            ("bu bbig", "Visit Bitzi",
             "top.output.location.href='http://www.fileheaven.org/'", "Bitzi");
            ("bu bbig", "Visit eMugle",
             "top.output.location.href='http://www.emugle.com/'", "eMugle");
          ]);
        ""
    ), ":\t\t\tview custom queries";

    "d", Arg_multiple (fun args o ->
        List.iter (fun arg ->
            CommonInteractive.download_file o arg) args;
        ""
    ), "<num> :\t\t\t\t$bfile to download$n";

    "force_download", Arg_none (fun o ->
	if !forceable_download = [] then
	  begin
            let output = (if o.conn_output = HTML then begin
                let buf = Buffer.create 100 in
                Printf.bprintf buf "\\<div class=\\\"cs\\\"\\>";
                html_mods_table_header buf "dllinkTable" "results" [];
                Printf.bprintf buf "\\<tr\\>";
                html_mods_td buf [ ("", "srh", "No download to force"); ];
                Printf.bprintf buf "\\</tr\\>\\</table\\>\\</div\\>\\</div\\>";
                Buffer.contents buf
              end
            else begin
                Printf.sprintf "No download to force"
            end) in
            _s output
	  end
        else
	  begin
	    let r = List.hd !forceable_download in
	      CommonNetwork.networks_iter (fun n ->
	        ignore (n.op_network_download r o.conn_user.ui_user_name));

            let output = (if o.conn_output = HTML then begin
                let buf = Buffer.create 100 in
                Printf.bprintf buf "\\<div class=\\\"cs\\\"\\>";
                html_mods_table_header buf "dllinkTable" "results" [];
                Printf.bprintf buf "\\<tr\\>";
                html_mods_td buf [ ("", "srh", "Forced start of "); ];
                Printf.bprintf buf "\\</tr\\>\\<tr class=\\\"dl-1\\\"\\>";
                html_mods_td buf [ ("", "sr", (List.hd r.result_names)); ];
                Printf.bprintf buf "\\</tr\\>\\</table\\>\\</div\\>\\</div\\>";
                Buffer.contents buf
              end
            else begin
                Printf.sprintf "Forced start of : %s" (List.hd r.result_names)
            end) in
            _s output
	  end;
    ), ":\t\t\tforce download of an already downloaded file";

    ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Options                                *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Options"
    [

    "set", Arg_two (fun name value o ->
	if user2_is_admin o.conn_user.ui_user_name then begin
        try
          try
            CommonInteractive.set_fully_qualified_options name value;
            Printf.sprintf "option %s value changed" name

          with _ ->
              Options.set_simple_option downloads_ini name value;
              Printf.sprintf "option %s value changed" name
        with e ->
            Printf.sprintf "Error %s" (Printexc2.to_string e)
	  end
	else
	  _s "You are not allowed to change options"
    ), "<option_name> <option_value> :\t$bchange option value$n";

    "save", Arg_multiple (fun args o ->
	if !allow_saving_ini_files then begin
        match args with
	  ["options"] -> DriverInteractive.save_config (); _s "options saved"
	| ["sources"] -> CommonComplexOptions.save_sources (); _s "sources saved"
	| ["backup"] -> CommonComplexOptions.backup_options (); _s "backup saved"
	| ["all"] ->
	       DriverInteractive.save_config ();
	       CommonComplexOptions.save_sources ();
	       CommonComplexOptions.backup_options ();
	        _s "options, sources and backup saved"
	| _ -> DriverInteractive.save_config ();
	       CommonComplexOptions.save_sources (); _s "options and sources saved"
	end else _s "base directory full, ini file saving disabled until core shutdown"
        ), "[<options|sources|backup>] :\tsave options and/or sources or backup (empty for options and sources)";

    "vo", Arg_none (fun o ->
        let buf = o.conn_buf in
        if use_html_mods o then begin

          if !!html_mods_use_js_helptext then
            Printf.bprintf buf "\\<div id=\\\"object1\\\" style=\\\"position:absolute; background-color:#FFFFDD;color:black;border-color:black;border-width:20px;font-size:8pt; visibility:visible; left:25px; top:-100px; z-index:+1\\\" onmouseover=\\\"overdiv=1;\\\"  onmouseout=\\\"overdiv=0; setTimeout(\\\'hideLayer()\\\',1000)\\\"\\>\\&nbsp;\\</div\\>";
            
          Printf.bprintf buf "\\<div class=\\\"friends\\\"\\>\\<table class=main cellspacing=0 cellpadding=0\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap title=\\\"Show shares Tab (also related for incoming directory)\\\" class=\\\"fbig fbigpad\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=shares'\\\"\\>Shares\\</a\\>\\</td\\>
%s
\\<td nowrap title=\\\"Show Web_infos Tab where you can add/remove automatic downloads like serverlists\\\" class=\\\"fbig fbigpad\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=vwi'\\\"\\>Web infos\\</a\\>\\</td\\>
\\<td nowrap title=\\\"Show Calendar Tab, there are informations about automatically jobs\\\" class=\\\"fbig fbigpad\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=vcal'\\\"\\>Calendar\\</a\\>\\</td\\>
\\<td nowrap title=\\\"Change to simple Webinterface without html_mods\\\" class=\\\"fbig fbigpad\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=html_mods'\\\"\\>Toggle html_mods\\</a\\>\\</td\\>
\\<td nowrap title=\\\"voo\\\" class=\\\"fbig pr fbigpad\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=voo+1'\\\"\\>Full Options\\</a\\>\\</td\\>
\\</tr\\>\\</table\\>
\\</td\\>\\</tr\\>
\\<tr\\>\\<td\\>"
(if (user2_is_admin o.conn_user.ui_user_name) then
  "\\<td nowrap title=\\\"Show users Tab where you can add/remove Users\\\" class=\\\"fbig fbigpad\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=users'\\\"\\>Users\\</a\\>\\</td\\>"
 else "");

            list_options_html o  (
              [
(* replaced strings_of_option_html by strings_of_option *)
                strings_of_option max_hard_upload_rate;
                strings_of_option max_hard_download_rate;
                strings_of_option telnet_port;
                strings_of_option gui_port;
                strings_of_option http_port;
                strings_of_option global_login;
                strings_of_option allowed_ips;
                strings_of_option set_client_ip;
                strings_of_option force_client_ip;
              ] );

            Printf.bprintf buf "\\</td\\>\\</tr\\>\\<tr\\>\\<td\\>\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap title=\\\"Toggle option helptext from javascript popup to html table\\\" class=\\\"fbig fbigb pr fbigpad\\\"\\>
\\<a onclick=\\\"javascript: {parent.fstatus.location.href='submit?q=set+html_mods_use_js_helptext+%s'; setTimeout('window.location.replace(window.location.href)',1000);return true;}\\\"\\>Toggle js_helptext\\</a\\>
\\</td\\>\\</tr\\>\\</table\\>\\</td\\>\\</tr\\>\\</table\\>\\</div\\>\\</br\\>" (if !!html_mods_use_js_helptext then "false" else "true");
            
            html_mods_table_one_row buf "downloaderTable" "downloaders" [
            ("", "srh", "!! press ENTER to send changes to core !!"); ]

          end

        else
          list_options o  (
            [
              strings_of_option max_hard_upload_rate;
              strings_of_option max_hard_download_rate;
              strings_of_option telnet_port;
              strings_of_option gui_port;
              strings_of_option http_port;
              strings_of_option global_login;
              strings_of_option allowed_ips;
              strings_of_option set_client_ip;
              strings_of_option force_client_ip;
            ]
          );

        "\nUse '$rvoo$n' for all options"
    ), ":\t\t\t\t\t$bdisplay options$n";




    "voo", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        if use_html_mods o then begin

            Printf.bprintf buf "\\<script type=\\\"text/javascript\\\"\\>
\\<!--
function pluginSubmit() {
var formID = document.getElementById(\\\"pluginForm\\\");
var v = formID.plugin.value;
location.href='submit?q=voo+'+v;
}
function submitHtmlModsStyle() {
var formID = document.getElementById(\\\"htmlModsStyleForm\\\");
var v = formID.modsStyle.value;
if (\\\"0123456789.\\\".indexOf(v) == -1)
{ parent.fstatus.location.href='submit?q=html_theme+\\\"'+v+'\\\"';} else
{ parent.fstatus.location.href='submit?q=html_mods_style+'+v;}
}
//--\\>
\\</script\\>";


            let tabnumber = ref 0 in
            let mtabs = ref 1 in

            if !!html_mods_use_js_helptext then
             Printf.bprintf buf "\\<div id=\\\"object1\\\" style=\\\"position:absolute; background-color:#FFFFDD;color:black;border-color:black;border-width:20px;font-size:8pt; visibility:visible; left:25px; top:-100px; z-index:+1\\\" onmouseover=\\\"overdiv=1;\\\"  onmouseout=\\\"overdiv=0; setTimeout(\\\'hideLayer()\\\',1000)\\\"\\>\\&nbsp;\\</div\\>";

            Printf.bprintf buf "\\<div class=\\\"vo\\\"\\>\\<table class=main cellspacing=0 cellpadding=0\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>";


            List.iter (fun (s,d) ->
                incr tabnumber; incr mtabs;
                Printf.bprintf buf "\\<td nowrap title=\\\"%s\\\" class=fbig\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=voo+%d';setTimeout('window.location.replace(window.location.href)',500)\\\"\\>%s\\</a\\>\\</td\\>"
                  d !tabnumber s
            ) [ ("Client", "Client related options & Up/Download limitations ") ; 
                ("Ports", "Interface ports, each Network port is stored in Network plugin options") ; 
                ("html", "Show Webinterface related options") ; 
                ("Delays", "Delays & timeouts") ; 
                ("Files", "File related options") ; 
                ("Mail", "eMail information options") ; 
                ("Net", "activate/deaktivate Networks, some TCP/IP & IP blocking options") ; 
                ("Misc", "miscellaneous") ];

            Printf.bprintf buf "
\\<td nowrap title=\\\"Show all options\\\" class=\\\"fbig\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=voo'\\\"\\>All\\</a\\>\\</td\\>
\\<td nowrap class=\\\"fbig fbig pr\\\"\\>
\\<form style=\\\"margin: 0px;\\\" name=\\\"pluginForm\\\" id=\\\"pluginForm\\\"
action=\\\"javascript:pluginSubmit();\\\"\\>
\\<select id=\\\"plugin\\\" name=\\\"plugin\\\"
style=\\\"padding: 0px; font-size: 10px; font-family: verdana\\\" onchange=\\\"this.form.submit()\\\"\\>
\\<option value=\\\"0\\\"\\>Plugins\n";

            let netlist = ref [] in
            List.iter (fun s ->
                incr tabnumber;
                netlist := !netlist @ [(s,!tabnumber)]

            ) (CommonInteractive.all_active_network_opfile_network_names ());

            let duplist = ref [] in
            let netname = ref "" in
            List.iter (fun tup ->
                let s = (fst tup) in
                let t = (snd tup) in
                if List.memq s !duplist then
                  netname := Printf.sprintf "%s+" s
                else netname := s;
                duplist := !duplist @ [!netname];
                Printf.bprintf buf "\\<option value=\\\"%d\\\"\\>%s\\</option\\>\n"
                  t !netname
            ) (List.sort (fun d1 d2 -> compare (fst d1) (fst d2)) !netlist);

            Printf.bprintf buf "\\</select\\>\\</td\\>\\</form\\>
\\</tr\\>\\</table\\>
\\</td\\>\\</tr\\>
\\<tr\\>\\<td\\>";

            list_options_html o (
              match args with
                [] | _ :: _ :: _ ->
                  let v=   CommonInteractive.all_simple_options () in
                  v

              | [arg] ->
                  try
                  let tab = int_of_string arg in
                  match tab with
                    1 ->
                      [
			strings_of_option global_login;
			strings_of_option set_client_ip;
			strings_of_option force_client_ip;
			strings_of_option run_as_user;
			strings_of_option run_as_useruid;
			strings_of_option max_upload_slots;
			strings_of_option dynamic_slots;
			strings_of_option max_hard_upload_rate;
			strings_of_option max_hard_download_rate;
			strings_of_option max_opened_connections;
			strings_of_option max_indirect_connections;
			strings_of_option max_connections_per_second;
			strings_of_option max_concurrent_downloads;
                      ]

                  | 2 ->
                      [
			strings_of_option gui_bind_addr;
			strings_of_option telnet_bind_addr;
			strings_of_option http_bind_addr;
			strings_of_option client_bind_addr;
			strings_of_option gui_port;
			strings_of_option telnet_port;
			strings_of_option http_port;
			strings_of_option http_realm;
			strings_of_option allowed_ips;
                      ]
                  | 3 ->
                      [
			strings_of_option html_mods_use_relative_availability;
			strings_of_option html_mods_human_readable;
			strings_of_option html_mods_vd_network;
			strings_of_option html_mods_vd_active_sources;
			strings_of_option html_mods_vd_age;
			strings_of_option html_mods_vd_last;
			strings_of_option html_mods_vd_prio;
			strings_of_option html_mods_show_pending;
			strings_of_option html_mods_load_message_file;
			strings_of_option html_mods_max_messages;
			strings_of_option html_mods_bw_refresh_delay;
			strings_of_option use_html_frames;
			strings_of_option html_frame_border;
			strings_of_option html_checkbox_vd_file_list;
			strings_of_option html_checkbox_search_file_list;
			strings_of_option commands_frame_height;
			strings_of_option html_vd_barheight;
			strings_of_option html_vd_chunk_graph;
			strings_of_option html_vd_chunk_graph_style;
			strings_of_option html_vd_chunk_graph_max_width;
			strings_of_option display_downloaded_results;
			strings_of_option vd_reload_delay;
			strings_of_option html_use_gzip;
			strings_of_option html_mods_use_js_tooltips;
			strings_of_option html_mods_js_tooltips_wait;
			strings_of_option html_mods_js_tooltips_timeout;
			strings_of_option html_mods_use_js_helptext;
			] @ (if Autoconf.has_gd then
			[strings_of_option html_mods_vd_gfx;] else []) @
			(if Autoconf.has_gd_jpg && Autoconf.has_gd_png
			 then [strings_of_option html_mods_vd_gfx_png;] else []) @
			(if Autoconf.has_gd then [
			strings_of_option html_mods_vd_gfx_remove;
			strings_of_option html_mods_vd_gfx_split;
			strings_of_option html_mods_vd_gfx_stack;
			strings_of_option html_mods_vd_gfx_fill;
			strings_of_option html_mods_vd_gfx_flip;
			strings_of_option html_mods_vd_gfx_mean;
			strings_of_option html_mods_vd_gfx_transparent;
			strings_of_option html_mods_vd_gfx_h;
			strings_of_option html_mods_vd_gfx_x_size;
			strings_of_option html_mods_vd_gfx_y_size;
			strings_of_option html_mods_vd_gfx_tag;
			strings_of_option html_mods_vd_gfx_tag_use_source;
			strings_of_option html_mods_vd_gfx_tag_source;
			strings_of_option html_mods_vd_gfx_tag_png;
			strings_of_option html_mods_vd_gfx_tag_enable_title;
			strings_of_option html_mods_vd_gfx_tag_title;
			strings_of_option html_mods_vd_gfx_tag_title_x_pos;
			strings_of_option html_mods_vd_gfx_tag_title_y_pos;
			strings_of_option html_mods_vd_gfx_tag_dl_x_pos;
			strings_of_option html_mods_vd_gfx_tag_dl_y_pos;
			strings_of_option html_mods_vd_gfx_tag_ul_x_pos;
			strings_of_option html_mods_vd_gfx_tag_ul_y_pos;
			strings_of_option html_mods_vd_gfx_tag_x_size;
			strings_of_option html_mods_vd_gfx_tag_y_size;
			] else [])
                  | 4 ->
                      [
			strings_of_option save_options_delay;
			strings_of_option update_gui_delay;
			strings_of_option server_connection_timeout;
			strings_of_option compaction_delay;
			strings_of_option min_reask_delay;
			strings_of_option buffer_writes;
			strings_of_option buffer_writes_delay;
			strings_of_option buffer_writes_threshold;
                      ]
                  | 5 ->
                      [
			strings_of_option previewer;
			strings_of_option temp_directory;
			strings_of_option hdd_temp_minfree;
			strings_of_option hdd_temp_stop_core;
			strings_of_option hdd_coredir_minfree;
			strings_of_option hdd_coredir_stop_core;
			strings_of_option hdd_send_warning_interval;
			strings_of_option file_started_cmd;
			strings_of_option file_completed_cmd;
			strings_of_option allow_browse_share;
			strings_of_option auto_commit;
			strings_of_option pause_new_downloads;
			strings_of_option create_dir_mask;
			strings_of_option create_file_sparse;
			strings_of_option log_file;
			strings_of_option log_file_size;
			strings_of_option log_size;
                      ]
                  | 6 ->
                      [
			strings_of_option mail;
			strings_of_option smtp_port;
			strings_of_option smtp_server;
			strings_of_option add_mail_brackets;
			strings_of_option filename_in_subject;
			strings_of_option url_in_mail;
                      ]
                  | 7 ->
                      ( (if Autoconf.donkey = "yes" then [(strings_of_option enable_overnet)] else [])
			@ [
			] @
			(if Autoconf.donkey = "yes" then [(strings_of_option enable_kademlia)] else [])
			@ [
			] @
			(if Autoconf.donkey = "yes" then [(strings_of_option enable_donkey)] else [])
			@ [
			] @
			(if Autoconf.bittorrent = "yes" then [(strings_of_option enable_bittorrent)] else [])
			@ [
			] @
			(if Autoconf.fasttrack = "yes" then [(strings_of_option enable_fasttrack)] else [])
			@ [
			] @
			(if Autoconf.opennapster = "yes" then [(strings_of_option enable_opennap)] else [])
			@ [
			] @
			(if Autoconf.soulseek = "yes" then [(strings_of_option enable_soulseek)] else [])
			@ [
			] @
			(if Autoconf.gnutella = "yes" then [(strings_of_option enable_gnutella)] else [])
			@ [
			] @
			(if Autoconf.gnutella2 = "yes" then [(strings_of_option enable_gnutella2)] else [])
			@ [
			] @
			(if Autoconf.direct_connect = "yes" then [(strings_of_option enable_directconnect)] else [])
			@ [
			] @
			(if Autoconf.openft = "yes" then [(strings_of_option enable_openft)] else [])
			@ [
			] @
			(if Autoconf.filetp = "yes" then [(strings_of_option enable_fileTP)] else [])
			@ [
			strings_of_option tcpip_packet_size;
			strings_of_option mtu_packet_size;
			strings_of_option minimal_packet_size;
			strings_of_option ip_blocking;
			strings_of_option ip_blocking_descriptions;
			strings_of_option ip_blocking_countries;
			strings_of_option ip_blocking_countries_block;
                      ])
                  | 8 ->
                      [
			strings_of_option term_ansi;
			strings_of_option messages_filter;
      strings_of_option comments_filter;
			strings_of_option max_displayed_results;
			strings_of_option max_name_len;
			strings_of_option max_filenames;
			strings_of_option max_client_name_len;
			strings_of_option emule_mods_count;
			strings_of_option emule_mods_showall;
			strings_of_option backup_options_format;
			strings_of_option backup_options_delay;
			strings_of_option backup_options_generations;
			strings_of_option small_files_slot_limit;
                      ]

                  | _ ->
                      let v = CommonInteractive.some_simple_options (tab - !mtabs) in
                      List.sort (fun d1 d2 -> compare d1 d2) v;
              with _ ->
                    let v = CommonInteractive.parse_simple_options args in
                    List.sort (fun d1 d2 -> compare d1 d2) v;


            );
            Printf.bprintf buf "
\\</td\\>\\</tr\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap title=\\\"Show shares Tab (also related for incoming directory)\\\" class=\\\"fbig fbigb\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=shares'\\\"\\>Shares\\</a\\>\\</td\\>
%s
\\<td nowrap title=\\\"Show Web_infos Tab where you can add/remove automatic downloads like serverlists\\\" class=\\\"fbig fbigb\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=vwi'\\\"\\>Web infos\\</a\\>\\</td\\>
\\<td nowrap title=\\\"Show Calendar Tab, there are informations about automatically jobs\\\" class=\\\"fbig fbigb\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=vcal'\\\"\\>Calendar\\</a\\>\\</td\\>
\\<td nowrap class=\\\"fbig fbigb pr\\\"\\>
\\<form style=\\\"margin: 0px;\\\" name=\\\"htmlModsStyleForm\\\" id=\\\"htmlModsStyleForm\\\"
action=\\\"javascript:submitHtmlModsStyle();\\\"\\>
\\<select id=\\\"modsStyle\\\" name=\\\"modsStyle\\\"
style=\\\"padding: 0px; font-size: 10px; font-family: verdana\\\" onchange=\\\"this.form.submit()\\\"\\>
\\<option value=\\\"0\\\"\\>style/theme\n"
(if (user2_is_admin o.conn_user.ui_user_name) then
  "\\<td nowrap title=\\\"Show users Tab where you can add/remove Users\\\" class=\\\"fbig fbigb\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=users'\\\"\\>Users\\</a\\>\\</td\\>"
 else "");

            Array.iteri (fun i style ->
                Printf.bprintf buf "\\<option value=\\\"%d\\\"\\>%s\\</option\\>\n" i style.style_name
	    ) CommonMessages.styles;

            if Sys.file_exists html_themes_dir then begin
              let list = Unix2.list_directory html_themes_dir in
              List.iter (fun d ->
                  if Unix2.is_directory (Filename.concat html_themes_dir d) then
                    let sd = (if String.length d > 11 then String.sub d 0 11 else d) in
                    Printf.bprintf buf "\\<option value=\\\"%s\\\"\\>%s\\</option\\>\n" d sd;
              ) (List.sort (fun d1 d2 -> compare d1 d2) list);
            end;
            
          Printf.bprintf buf "\\</select\\>\\</td\\>\\</tr\\>\\</form\\>\\</table\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap title=\\\"Change to simple Webinterface without html_mods\\\" class=\\\"fbig fbigb fbigpad\\\"\\>\\<a onclick=\\\"javascript:window.location.href='submit?q=html_mods'\\\"\\>toggle html_mods\\</a\\>\\</td\\>
\\<td nowrap title=\\\"Toggle option helptext from javascript popup to html table\\\" class=\\\"fbig fbigb pr fbigpad\\\"\\>
\\<a onclick=\\\"javascript: {parent.fstatus.location.href='submit?q=set+html_mods_use_js_helptext+%s'; setTimeout('window.location.replace(window.location.href)',1000);return true;}\\\"\\>Toggle js_helptext\\</a\\>
\\</td\\>\\</tr\\>\\</table\\>\\</td\\>\\</tr\\>\\</table\\>\\</div\\>\\</br\\>" (if !!html_mods_use_js_helptext then "false" else "true");
          html_mods_table_one_row buf "downloaderTable" "downloaders" [
          ("", "srh", "!! press ENTER to send changes to core !!"); ];
          end
                     
        else begin
            list_options o (CommonInteractive.parse_simple_options args)
          end;
        ""
    ), ":\t\t\t\t\tprint all options";

    "vwi", Arg_none (fun o ->
        let buf = o.conn_buf in
        if use_html_mods o then begin
            Printf.bprintf buf "\\<div class=\\\"shares\\\"\\>\\<table class=main cellspacing=0 cellpadding=0\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap class=\\\"fbig pr\\\"\\>\\<a onclick=\\\"javascript: {
                   var getdir = prompt('Input: <kind> <URL>','server.met URL')
                   parent.fstatus.location.href='submit?q=urladd+' + encodeURIComponent(getdir);
                   setTimeout('window.location.reload()',1000);
                    }\\\"\\>Add URL\\</a\\>
\\</td\\>
\\</tr\\>\\</table\\>
\\</td\\>\\</tr\\>
\\<tr\\>\\<td\\>";

            if !!web_infos = [] then
              html_mods_table_one_row buf "serversTable" "servers" [
                ("", "srh", "no jobs defined"); ]
	    else begin

    	      html_mods_table_header buf "web_infoTable" "vo" [
	        ( "0", "srh ac", "Click to remove URL", "Remove" ) ;
	        ( "0", "srh", "Option type", "Type" ) ;
	        ( "0", "srh", "Option delay", "Delay" ) ;
	        ( "0", "srh", "Option value", "Value" ) ] ;

              let counter = ref 0 in

              List.iter (fun (kind, period, url) ->
                incr counter;
                Printf.bprintf buf "\\<tr class=\\\"%s\\\"\\>"
                (if !counter mod 2 == 0 then "dl-1" else "dl-2");
		Printf.bprintf buf "
        \\<td title=\\\"Click to remove URL\\\"
        onMouseOver=\\\"mOvr(this);\\\"
        onMouseOut=\\\"mOut(this);\\\"
        onClick=\\\'javascript:{
	parent.fstatus.location.href=\\\"submit?q=urlremove+\\\\\\\"%s\\\\\\\"\\\"
        setTimeout(\\\"window.location.reload()\\\",1000);}'
        class=\\\"srb\\\"\\>Remove\\</td\\>" (Url.encode url);
          Printf.bprintf buf "
              \\<td title=\\\"%s\\\" class=\\\"sr\\\"\\>%s\\</td\\>
	      \\<td class=\\\"sr\\\"\\>%d\\</td\\>"  url kind period;
          Printf.bprintf buf "
              \\<td class=\\\"sr\\\"\\>%s\\</td\\>
              \\</tr\\>" url
              ) !!web_infos;
	    end;
            Printf.bprintf buf "\\</table\\>\\</td\\>\\<tr\\>\\</table\\>\\</div\\>\\<P\\>";

    	    html_mods_table_header buf "web_infoTable" "vo" [
	      ( "0", "srh", "Web kind", "Kind" );
	      ( "0", "srh", "Description", "Type" ) ];

            let counter = ref 0 in
            List.iter (fun (kind, data) ->
                incr counter;
                Printf.bprintf buf "\\<tr class=\\\"%s\\\"\\>"
                (if !counter mod 2 == 0 then "dl-1" else "dl-2");
		Printf.bprintf buf "
              \\<td class=\\\"sr\\\"\\>%s\\</td\\>
	      \\<td class=\\\"sr\\\"\\>%s\\</td\\>" kind data.description
            ) !CommonWeb.file_kinds;

            Printf.bprintf buf "\\</table\\>\\</td\\>\\<tr\\>\\</table\\>\\</div\\>\\<P\\>";
	    print_option_help o web_infos

          end
        else
	    begin
	      Printf.bprintf buf "kind / period / url :\n";
	      List.iter (fun (kind, period, url) ->
	          Printf.bprintf buf "%s ; %d ; %s\n"  kind period url
	      ) !!web_infos;
	      Printf.bprintf buf "\nAllowed values for kind:\n";
	      List.iter (fun (kind, data) ->
	          Printf.bprintf buf "%s - %s\n" kind data.description
	      ) !CommonWeb.file_kinds
	    end;
        ""
    ), ":\t\t\t\t\tprint web_infos options";

    "options", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          [] ->
            Printf.bprintf buf "Available sections for options: \n";

            List.iter (fun s ->
                Printf.bprintf buf "  $b%s$n\n" (section_name s);
            ) (sections downloads_ini);

            networks_iter (fun r ->
                List.iter (fun file ->
                    List.iter (fun s ->
                        Printf.bprintf buf "  $b%s::%s$n\n"
                          r.network_name
                          (section_name s);
                    ) (sections file)
                ) r.network_config_file
            );
            "\n\nUse 'options section' to see options in this section"

        | ss ->

            let print_section name prefix (s: options_section) =
              if List.mem name ss then
                Printf.bprintf buf "Options in section $b%s$n:\n" name;
              List.iter (fun o ->
                  Printf.bprintf buf "  %s [$r%s%s$n]= $b%s$n\n"
                    (if o.option_desc = "" then
                      o.option_name else o.option_desc)
                  prefix o.option_name o.option_value
              ) (strings_of_section_options "" s)
            in
            List.iter (fun s ->
                print_section (section_name s) "" s
            ) (sections downloads_ini);

            networks_iter (fun r ->
                List.iter (fun file ->
                    List.iter (fun s ->
                        print_section
                          (Printf.sprintf "%s::%s" r.network_name
                            (section_name s)) (r.network_shortname ^ "-") s
                    ) (sections file)
                ) r.network_config_file
            );

            "\nUse '$rset option \"value\"$n' to change a value where options is
the name between []"
    ), ":\t\t\t\t$bprint options values by section$n";

  ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Sharing                                *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Sharing"
    [

    "reshare", Arg_none (fun o ->
        let buf = o.conn_buf in
        shared_check_files ();
        if o.conn_output = HTML then
          html_mods_table_one_row buf "serversTable" "servers" [
            ("", "srh", "Reshare check done"); ]
        else
          Printf.bprintf buf "Reshare check done";
        _s ""
    ), ":\t\t\t\tcheck shared files for removal";

     "debug_disk", Arg_one (fun arg o ->
         let buf = o.conn_buf in
	 let print_i64o = function
	   | None -> "Unknown"
	   | Some v -> Printf.sprintf "%Ld" v in
         Printf.bprintf buf "working on dir %s\n" arg;
         Printf.bprintf buf "bsize %s\n" (print_i64o (Unix32.bsize arg));
         Printf.bprintf buf "blocks %s\n" (print_i64o (Unix32.blocks arg));
         Printf.bprintf buf "bfree %s\n" (print_i64o (Unix32.bfree arg));
         Printf.bprintf buf "bavail %s\n" (print_i64o (Unix32.bavail arg));
         Printf.bprintf buf "fnamelen %s\n" (print_i64o (Unix32.fnamelen arg));
         Printf.bprintf buf "filesystem %s\n" (Unix32.filesystem arg);
	 let print_i64o_amount = function
	   | None -> "Unknown"
	   | Some v -> Printf.sprintf "%Ld - %s" v (size_of_int64 v) in
         Printf.bprintf buf "disktotal %s\n" (print_i64o_amount (Unix32.disktotal arg));
         Printf.bprintf buf "diskfree %s\n" (print_i64o_amount (Unix32.diskfree arg));
         Printf.bprintf buf "diskused %s\n" (print_i64o_amount (Unix32.diskused arg));
	 let print_percento = function
	   | None -> "Unknown"
	   | Some p -> Printf.sprintf "%d%%" p in
         Printf.bprintf buf "percentused %s\n" (print_percento (Unix32.percentused arg));
         Printf.bprintf buf "percentfree %s\n" (print_percento (Unix32.percentfree arg));
	 let stat = Unix.stat arg in
         Printf.bprintf buf "\nstat_device %d\n" stat.Unix.st_dev;
         Printf.bprintf buf "stat_inode %d\n" stat.Unix.st_ino;

         _s ""
     ), "debug command (example: disk .)";

     "debug_dir", Arg_one (fun arg o ->
         let buf = o.conn_buf in
	 let filelist = Unix2.list_directory arg in
         Printf.bprintf buf "%d entries in dir %s\n" (List.length filelist) arg;
	 List.iter (fun file ->
           Printf.bprintf buf "%s\n     %s\nMime %s\n\n"
	     file
	     (match Magic.M.magic_fileinfo (Filename.concat arg file) false with
	        None -> "unknown"
	      | Some fileinfo -> fileinfo)
	     (match Magic.M.magic_fileinfo (Filename.concat arg file) true with
	        None -> "unknown"
	      | Some fileinfo -> fileinfo)
	 ) filelist;
         _s ""
     ), "debug command (example: disk .)";

     "debug_fileinfo", Arg_one (fun arg o ->
         let buf = o.conn_buf in
	 (try
	    let s = Unix.stat arg in
            Printf.bprintf buf "st_dev %d\n" s.Unix.st_dev;
            Printf.bprintf buf "st_ino %d\n" s.Unix.st_ino;
            Printf.bprintf buf "st_uid %d\n" s.Unix.st_uid;
            Printf.bprintf buf "st_gid %d\n" s.Unix.st_gid;
            Printf.bprintf buf "st_size %d\n" s.Unix.st_size;
	    let user,group = Unix32.owner arg in
            Printf.bprintf buf "username %s\n" user;
            Printf.bprintf buf "groupname %s\n" group;
	  with e -> Printf.bprintf buf "Error %s when opening %s\n" (Printexc2.to_string e) arg);
         _s ""
     ), "debug command (example: file .)";

     "debug_rlimit", Arg_none (fun o ->
         let buf = o.conn_buf in
	 let cpu = Unix2.ml_getrlimit Unix2.RLIMIT_CPU in
	 let fsize = Unix2.ml_getrlimit Unix2.RLIMIT_FSIZE in
	 let data = Unix2.ml_getrlimit Unix2.RLIMIT_DATA in
	 let stack = Unix2.ml_getrlimit Unix2.RLIMIT_STACK in
	 let core = Unix2.ml_getrlimit Unix2.RLIMIT_CORE in
	 let rss = Unix2.ml_getrlimit Unix2.RLIMIT_RSS in
	 let nprof = Unix2.ml_getrlimit Unix2.RLIMIT_NPROF in
	 let nofile = Unix2.ml_getrlimit Unix2.RLIMIT_NOFILE in
	 let memlock = Unix2.ml_getrlimit Unix2.RLIMIT_MEMLOCK in
         let rlimit_as = Unix2.ml_getrlimit Unix2.RLIMIT_AS in
         Printf.bprintf buf "cpu %d %d\n" cpu.Unix2.rlim_cur cpu.Unix2.rlim_max;
         Printf.bprintf buf "fsize %d %d\n" fsize.Unix2.rlim_cur fsize.Unix2.rlim_max;
         Printf.bprintf buf "data %d %d\n" data.Unix2.rlim_cur data.Unix2.rlim_max;
         Printf.bprintf buf "stack %d %d\n" stack.Unix2.rlim_cur stack.Unix2.rlim_max;
         Printf.bprintf buf "core %d %d\n" core.Unix2.rlim_cur core.Unix2.rlim_max;
         Printf.bprintf buf "rss %d %d\n" rss.Unix2.rlim_cur rss.Unix2.rlim_max;
         Printf.bprintf buf "nprof %d %d\n" nprof.Unix2.rlim_cur nprof.Unix2.rlim_max;
         Printf.bprintf buf "nofile %d %d\n" nofile.Unix2.rlim_cur nofile.Unix2.rlim_max;
         Printf.bprintf buf "memlock %d %d\n" memlock.Unix2.rlim_cur memlock.Unix2.rlim_max;
         Printf.bprintf buf "as %d %d\n" rlimit_as.Unix2.rlim_cur rlimit_as.Unix2.rlim_max;
         _s ""
     ), "debug command";

    "shares", Arg_none (fun o ->

        let buf = o.conn_buf in

        if use_html_mods o then begin
            Printf.bprintf buf "\\<div class=\\\"shares\\\"\\>\\<table class=main cellspacing=0 cellpadding=0\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap class=\\\"fbig pr\\\"\\>\\<a onclick=\\\"javascript: {
                   var getdir = prompt('Input: <priority#> <directory> (surround dir with quotes if necessary)','0 /home/mldonkey/share')
                   parent.fstatus.location.href='submit?q=share+' + encodeURIComponent(getdir);
                   setTimeout('window.location.reload()',1000);
                    }\\\"\\>Add Share\\</a\\>
\\</td\\>
\\</tr\\>\\</table\\>
\\</td\\>\\</tr\\>
\\<tr\\>\\<td\\>";

            html_mods_table_header buf "sharesTable" "shares" [
               ( "0", "srh ac", "Click to unshare directory", "Unshare" ) ;
               ( "1", "srh ar", "Priority", "P" ) ;
               ( "0", "srh", "Directory", "Directory" ) ;
               ( "0", "srh", "Strategy", "Strategy" ) ;
               ( "1", "srh ar", "HDD used", "used" ) ;
               ( "1", "srh ar", "HDD free", "free" ) ;
               ( "1", "srh ar", "% free", "% free" ) ;
               ( "0", "srh", "Filesystem", "FS" ) ];

            let counter = ref 0 in

            List.iter (fun shared_dir ->
		let dir = shared_dir.shdir_dirname in
		incr counter;
		Printf.bprintf buf "\\<tr class=\\\"%s\\\"\\>
        \\<td title=\\\"Click to unshare this directory\\\"
        onMouseOver=\\\"mOvr(this);\\\"
        onMouseOut=\\\"mOut(this);\\\"
        onClick=\\\'javascript:{
        parent.fstatus.location.href=\\\"submit?q=unshare+\\\\\\\"%s\\\\\\\"\\\"
        setTimeout(\\\"window.location.reload()\\\",1000);}'
        class=\\\"srb\\\"\\>Unshare\\</td\\>
        \\<td class=\\\"sr ar\\\"\\>%d\\</td\\>
        \\<td class=\\\"sr\\\"\\>%s\\</td\\>
        \\<td class=\\\"sr\\\"\\>%s\\</td\\>
        \\<td class=\\\"sr ar\\\"\\>%s\\</td\\>
        \\<td class=\\\"sr ar\\\"\\>%s\\</td\\>
        \\<td class=\\\"sr ar\\\"\\>%s\\</td\\>
        \\<td class=\\\"sr\\\"\\>%s\\</td\\>\\</tr\\>"
		(if !counter mod 2 == 0 then "dl-1" else "dl-2")
		(Url.encode dir)
		shared_dir.shdir_priority
		dir
		shared_dir.shdir_strategy
		(match Unix32.diskused dir with
		| None -> "---"
		| Some du -> size_of_int64 du)
		(match Unix32.diskfree dir with
		| None -> "---"
		| Some df -> size_of_int64 df)
		(match Unix32.percentfree dir with
		| None -> "---"
		| Some p -> Printf.sprintf "%d%%" p)
	        (Unix32.filesystem dir);
            )
            !!shared_directories;
  
            Printf.bprintf buf "\\</table\\>\\</td\\>\\<tr\\>\\</table\\>\\</div\\>\\<P\\>";
	    print_option_help o shared_directories
          end
        else
          begin

            Printf.bprintf buf "Shared directories:\n";
            List.iter (fun sd ->
                Printf.bprintf buf "  %d %s %s\n"
                sd.shdir_priority sd.shdir_dirname sd.shdir_strategy)
            !!shared_directories;

          end;
        ""
    ), ":\t\t\t\tprint shared directories";

    "share", Arg_multiple (fun args o ->
        let (prio, arg, strategy) = match args with
          | [prio; arg; strategy] -> int_of_string prio, arg, strategy
          | [prio; arg] -> int_of_string prio, arg, "only_directory"
          | [arg] -> 0, arg, "only_directory"
          | _  -> failwith "Bad number of arguments"
        in

        let shdir = {
            shdir_dirname = arg;
            shdir_priority = prio;
            shdir_networks = [];
            shdir_strategy = strategy;
          } in

        if Unix2.is_directory arg then
          if not (List.mem shdir !!shared_directories) then begin
              shared_directories =:= shdir :: !!shared_directories;
              shared_add_directory shdir;
              "directory added"
            end (* else
            if not (List.mem (arg, prio) !!shared_directories) then begin
              shared_directories =:= (arg, prio) :: List.remove_assoc arg !!shared_directories;
              shared_add_directory (arg, prio);
              "prio changed"
            end *) else
            "directory already shared"
        else
          "no such directory"
    ), "<priority> <dir> [<strategy>] :\tshare directory <dir> with <priority> [and sharing strategy <strategy>]";

    "unshare", Arg_one (fun arg o ->

        let found = ref false in
        shared_directories =:= List.filter (fun sd ->
            let diff = sd.shdir_dirname <> arg in
            if not diff then begin
	      found := true;
	      shared_iter (fun s ->
	        let impl = as_shared_impl s in
		  if (Filename.dirname impl.impl_shared_fullname) = arg
		    then shared_unshare s
	      )
	    end;
            diff
        ) !!shared_directories;
        if !found then begin
            CommonShared.shared_check_files ();
            _s "directory removed"
          end else
          _s "directory already unshared"

    ), "<dir> :\t\t\t\tshare directory <dir>";

    "upstats", Arg_none (fun o ->
        let buf = o.conn_buf in

        if not (user2_can_view_uploads o.conn_user.ui_user_name) then
          begin
            if use_html_mods o then
              html_mods_table_one_row buf "upstatsTable" "upstats" [
                ("", "srh", "You are not allowed to see upload statistics") ]
            else
              print_command_result o buf "You are not allowed to see upload statistics"
          end
        else
	  begin
	    let list = ref [] in
	    shared_iter (fun s ->
	      let impl = as_shared_impl s in
	      list := impl :: !list
	    );
	    print_upstats o !list None;
	  end;
        _s ""
    ), ":\t\t\t\tstatistics on upload";

    "links", Arg_none (fun o ->
        let buf = o.conn_buf in
        if not (user2_can_view_uploads o.conn_user.ui_user_name) then
          begin
            if use_html_mods o then
              html_mods_table_one_row buf "upstatsTable" "upstats" [
                ("", "srh", "You are not allowed to see shared files list") ]
            else
              Printf.bprintf buf "You are not allowed to see shared files list\n"
          end
        else begin

        let list = ref [] in
        shared_iter (fun s ->
          let impl = as_shared_impl s in
          list := impl :: !list
        );

        let list =
          List.sort ( fun f1 f2 ->
            String.compare
              (Filename.basename f1.impl_shared_codedname)
              (Filename.basename f2.impl_shared_codedname)
        ) !list in

        List.iter (fun impl ->
          if (impl.impl_shared_id <> Md4.null) then
	    Printf.bprintf buf "%s\n" (file_print_ed2k_link
	      (Filename.basename impl.impl_shared_codedname)
	      impl.impl_shared_size impl.impl_shared_id);
        ) list;
        end;
        "Done"
    ), ":\t\t\t\t\tlist links of shared files";

    "uploaders", Arg_none (fun o ->
        let buf = o.conn_buf in

        if not (user2_can_view_uploads o.conn_user.ui_user_name) then
          begin
            begin
              if use_html_mods o then
                html_mods_table_one_row buf "upstatsTable" "upstats" [
                  ("", "srh", "You are not allowed to see uploaders list") ]
              else
                Printf.bprintf buf "You are not allowed to see uploaders list\n";
            end;
            ""
          end
        else begin

        let nuploaders = Intmap.length !uploaders in

        if use_html_mods o then

          begin

            let counter = ref 0 in
            Printf.bprintf buf "\\<div class=\\\"uploaders\\\"\\>";
            html_mods_table_one_row buf "uploadersTable" "uploaders" [
              ("", "srh", Printf.sprintf "Total upload slots: %d (%d) | Pending slots: %d\n" nuploaders
                (Fifo.length CommonUploads.upload_clients)
                (Intmap.length !CommonUploads.pending_slots_map)); ];
(*             Printf.bprintf buf "\\<div class=\\\"uploaders\\\"\\>Total upload slots: %d (%d) | Pending slots: %d\n" nuploaders
              (Fifo.length CommonUploads.upload_clients)
            (Intmap.length !CommonUploads.pending_slots_map);
 *)
            if nuploaders > 0 then

              begin

                html_mods_table_header buf "uploadersTable" "uploaders" ([
                  ( "1", "srh ac", "Client number", "Num" ) ;
                  ( "0", "srh", "Network", "Network" ) ;
                  ( "0", "srh", "Connection type [I]ndirect [D]irect", "C" ) ;
                  ( "0", "srh", "Client name", "Client name" ) ;
                  ( "0", "srh", "Secure User Identification [N]one, [P]assed, [F]ailed", "S" ) ;
                  ( "0", "srh", "IP address", "IP address" ) ;
		  ] @ (if !Geoip.active then [( "0", "srh", "Country Code/Name", "CC" )] else []) @ [
                  ( "0", "srh", "Connected time (minutes)", "CT" ) ;
                  ( "0", "srh", "Client brand", "CB" ) ;
                  ( "0", "srh", "Client release", "CR" ) ;
                  ] @
                  (if !!emule_mods_count then [( "0", "srh", "eMule MOD", "EM" )] else [])
                  @ [
                  ( "0", "srh ar", "Total DL bytes from this client for all files", "DL" ) ;
                  ( "0", "srh ar", "Total UL bytes to this client for all files", "UL" ) ;
                  ( "0", "srh", "Filename", "Filename" ) ]);

                List.iter (fun c ->
                    try
                      let i = client_info c in
                      if is_connected i.client_state then begin
                          incr counter;

                          Printf.bprintf buf "\\<tr class=\\\"%s\\\"
                        title=\\\"[%d] Add as friend (avg: %.1f KB/s)\\\"
                        onMouseOver=\\\"mOvr(this);\\\"
                        onMouseOut=\\\"mOut(this);\\\"
                        onClick=\\\"parent.fstatus.location.href='submit?q=friend_add+%d'\\\"\\>"
                            ( if (!counter mod 2 == 0) then "dl-1" else "dl-2";) (client_num c)
                          ( float_of_int (Int64.to_int i.client_uploaded / 1024) /.
                              float_of_int (max 1 ((last_time ()) - i.client_connect_time)) )
                          (client_num c);

                          html_mods_td buf [
                            ("", "sr", Printf.sprintf "%d" (client_num c)); ];

                          let ips,cc,cn = string_of_kind_geo i.client_kind in

                          client_print_html c o;
                          html_mods_td buf ([
                            ("", "sr", (match i.client_sui_verified with
                              | None -> "N"
                               | Some b -> if b then "P" else "F"
                            )); 
                            ("", "sr", ips);
                            ] @ (if !Geoip.active then [(cn, "sr", cc)] else []) @ [
                            ("", "sr", Printf.sprintf "%d" (((last_time ()) - i.client_connect_time) / 60));
                            ("", "sr", i.client_software);
                            ("", "sr", i.client_release);
                            ] @
                            (if !!emule_mods_count then [("", "sr", i.client_emulemod)] else [])
                            @ [
                            ("", "sr ar", size_of_int64 i.client_downloaded);
                            ("", "sr ar", size_of_int64 i.client_uploaded);
                            ("", "sr", (match i.client_upload with
                                  Some cu -> cu
                                | None -> "") ) ]);

                          Printf.bprintf buf "\\</tr\\>"
                        end
                    with _ -> ()
                ) (List.sort
                    (fun c1 c2 -> compare (client_num c1) (client_num c2))
                  (Intmap.to_list !uploaders));
                Printf.bprintf buf "\\</table\\>\\</div\\>";
              end;

            if !!html_mods_show_pending && Intmap.length !CommonUploads.pending_slots_map > 0 then

              begin
                Printf.bprintf buf "\\<br\\>\\<br\\>";
                html_mods_table_header buf "uploadersTable" "uploaders" ([
                  ( "1", "srh ac", "Client number", "Num" ) ;
                  ( "0", "srh", "Network", "Network" ) ;
                  ( "0", "srh", "Connection type [I]ndirect [D]irect", "C" ) ;
                  ( "0", "srh", "Client name", "Client name" ) ;
                  ( "0", "srh", "Client brand", "CB" ) ;
                  ( "0", "srh", "Client release", "CR" ) ;
                  ] @
                  (if !!emule_mods_count then [( "0", "srh", "eMule MOD", "EM" )] else [])
                  @ [
                  ( "0", "srh ar", "Total DL bytes from this client for all files", "DL" ) ;
                  ( "0", "srh ar", "Total UL bytes to this client for all files", "UL" ) ;
                  ( "0", "srh", "IP address", "IP address" ) ]);

                Intmap.iter (fun cnum c ->

                    try
                      let i = client_info c in
                      incr counter;

                      Printf.bprintf buf "\\<tr class=\\\"%s\\\"
					title=\\\"Add as Friend\\\" onMouseOver=\\\"mOvr(this);\\\" onMouseOut=\\\"mOut(this);\\\"
					onClick=\\\"parent.fstatus.location.href='submit?q=friend_add+%d'\\\"\\>"
                        ( if (!counter mod 2 == 0) then "dl-1" else "dl-2";) cnum;

                      html_mods_td buf [
                        ("", "sr", Printf.sprintf "%d" (client_num c)); ];

                      client_print_html c o;

                      html_mods_td buf ([
                        ("", "sr", i.client_software);
                        ("", "sr", i.client_release);
                        ] @
                        (if !!emule_mods_count then [("", "sr", i.client_emulemod )] else [])
                        @ [
                        ("", "sr ar", size_of_int64 i.client_downloaded);
                        ("", "sr ar", size_of_int64 i.client_uploaded);
                        ("", "sr", string_of_kind i.client_kind); ]);

                      Printf.bprintf buf "\\</tr\\>";
                    with _ -> ();

                ) !CommonUploads.pending_slots_map;
                Printf.bprintf buf "\\</table\\>\\</div\\>";

              end;

            Printf.bprintf buf "\\</div\\>";
            ""
          end
        else
          begin

            Intmap.iter (fun _ c ->
                try
                  let i = client_info c in

                  client_print c o;
                  Printf.bprintf buf "client: %s downloaded: %s uploaded: %s\n" i.client_software (Int64.to_string i.client_downloaded) (Int64.to_string i.client_uploaded);
                  match i.client_upload with
                    Some cu ->
                      Printf.bprintf buf "      filename: %s\n" cu
                  | None -> ()
                with _ ->
                    Printf.bprintf buf "no info on client %d\n" (client_num c )
            ) !uploaders;

            Printf.sprintf "Total upload slots: %d (%d) | Pending slots: %d\n" nuploaders
              (Fifo.length CommonUploads.upload_clients)
            (Intmap.length !CommonUploads.pending_slots_map);


          end
      end


    ), ":\t\t\t\tshow users currently uploading";


  ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Downloads                              *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Downloads"
    [

    "priority", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          p :: files ->
            let absolute, p = if String2.check_prefix p "=" then
                true, int_of_string (String2.after p 1)
              else false, int_of_string p in
            List.iter (fun arg ->
                try
                  let file = file_find (int_of_string arg) in
                  let priority = if absolute then p
                    else (file_priority file) + p in
                  let priority = if priority < -100 then -100 else
                    if priority > 100 then 100 else priority in
                  set_file_priority file priority;
                  Printf.bprintf buf "Setting priority of %s to %d\n"
                    (file_best_name file) (file_priority file);
                with _ -> failwith (Printf.sprintf "No file number %s" arg)
            ) files;
            force_download_quotas ();
            _s "done"
        | [] -> "Bad number of args"

    ), "<priority> <files numbers> :\tchange file priorities";

    "confirm", Arg_one (fun arg o ->
        match String.lowercase arg with
          "yes" | "y" | "true" ->
            List.iter (fun file ->
                try
                  file_cancel file o.conn_user.ui_user_name
                with e ->
                    lprintf "Exception %s in cancel file %d\n"
                      (Printexc2.to_string e) (file_num file)
            ) !to_cancel;
            to_cancel := [];
            _s "Files cancelled"
        | "no" | "n" | "false" ->
            to_cancel := [];
            _s "cancel aborted"
        | "what" | "w" ->
            files_to_cancel o
        | _ -> failwith "Invalid argument"
    ), "<yes|no|what> :\t\t\tconfirm cancellation";

    "test_recover", Arg_one (fun num o ->

        let num = int_of_string num in
        let file = file_find num in
        let segments = CommonFile.recover_bytes file in
        let buf = o.conn_buf in
        Printf.bprintf buf "Segments:\n";
        let downloaded = ref zero in
        List.iter (fun (begin_pos, end_pos) ->
            Printf.bprintf buf "   %Ld - %Ld\n" begin_pos end_pos;
            downloaded := !downloaded ++ (end_pos -- begin_pos);
        ) segments;
        Printf.sprintf "Downloaded: %Ld\n" !downloaded
    ), "<num> :\t\t\tprint the segments downloaded in file";


    "cancel", Arg_multiple (fun args o ->

        let file_cancel num =
          if not (List.memq num !to_cancel) then
            to_cancel := num :: !to_cancel
        in
        if args = ["all"] && user2_is_admin o.conn_user.ui_user_name then
          List.iter (fun file ->
              file_cancel file
          ) !!files
        else
          List.iter (fun num ->
              let num = int_of_string num in
              List.iter (fun file ->
                  if (as_file_impl file).impl_file_num = num then begin
                      lprintf "TRY TO CANCEL FILE\n";
                      file_cancel file
                    end
              ) !!files) args;
        files_to_cancel o
    ), "<num> :\t\t\t\tcancel download (use arg 'all' for all files)";

    "downloaders", Arg_none (fun o ->
        let buf = o.conn_buf in

        if use_html_mods o then
          html_mods_table_header buf "downloadersTable" "downloaders" ([
              ( "1", "srh ac", "Client number (click to add as friend)", "Num" ) ;
              ( "0", "srh", "Client state", "CS" ) ;
              ( "0", "srh", "Client name", "Name" ) ;
              ( "0", "srh", "Client brand", "CB" ) ;
              ( "0", "srh", "Client release", "CR" ) ;
            ] @
              (if !!emule_mods_count then [( "0", "srh", "eMule MOD", "EM" )] else [])
            @ [
              ( "0", "srh", "Overnet [T]rue, [F]alse", "O" ) ;
              ( "1", "srh ar", "Connected time (minutes)", "CT" ) ;
              ( "0", "srh", "Connection [I]ndirect, [D]irect", "C" ) ;
              ( "0", "srh", "Secure User Identification [N]one, [P]assed, [F]ailed", "S" ) ;
              ( "0", "srh", "IP address", "IP address" ) ;
              ] @ (if !Geoip.active then [( "0", "srh", "Country Code/Name", "CC" )] else []) @ [ 
              ( "1", "srh ar", "Total UL bytes to this client for all files", "UL" ) ;
              ( "1", "srh ar", "Total DL bytes from this client for all files", "DL" ) ;
              ( "0", "srh", "Filename", "Filename" ) ]);

        let counter = ref 0 in

        List.iter
          (fun file ->
            if (CommonFile.file_downloaders file o !counter) then counter := 0 else counter := 1;
        ) !!files;

        if use_html_mods o then Printf.bprintf buf "\\</table\\>\\</div\\>";

        ""
    ) , ":\t\t\t\tdisplay downloaders list";

    "verify_chunks", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        match args with
          [arg] ->
            let num = int_of_string arg in
              List.iter
                (fun file -> if (as_file_impl file).impl_file_num = num then
                    begin
                      Printf.bprintf  buf "Verifying Chunks of file %d" num;
                      file_check file;
                    end
              )
              !!files;
            ""
        | _ -> ();
            _s "done"
    ), "<num> :\t\t\tverify chunks of file <num>";

    "pause", Arg_multiple (fun args o ->
        if args = ["all"] && user2_is_admin o.conn_user.ui_user_name then
          List.iter (fun file ->
              file_pause file admin_user;
          ) !!files
        else
          List.iter (fun num ->
              let num = int_of_string num in
              List.iter (fun file ->
                  if (as_file_impl file).impl_file_num = num then
                      file_pause file o.conn_user.ui_user_name
              ) !!files) args; ""
    ), "<num> :\t\t\t\tpause a download (use arg 'all' for all files)";

    "resume", Arg_multiple (fun args o ->
        if args = ["all"] && user2_is_admin o.conn_user.ui_user_name then
          List.iter (fun file ->
              file_resume file admin_user
          ) !!files
        else
          List.iter (fun num ->
              let num = int_of_string num in
              List.iter (fun file ->
                  if (as_file_impl file).impl_file_num = num then
                      file_resume file o.conn_user.ui_user_name
              ) !!files) args; ""
    ), "<num> :\t\t\t\tresume a paused download (use arg 'all' for all files)";

    "commit", Arg_none (fun o ->
        List.iter (fun file ->
            file_commit file
        ) !!done_files;
        let buf = o.conn_buf in
        if o.conn_output = HTML then
          html_mods_table_one_row buf "serversTable" "servers" [
            ("", "srh", "Commited"); ]
        else
          Printf.bprintf buf "Commited";
        ""
    ) , ":\t\t\t\t$bmove downloaded files to incoming directory$n";

    "vd", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        let list = user2_filter_files !!files o.conn_user.ui_user_name in
        let filelist = List2.tail_map file_info list in
        match args with
          | ["queued"] ->
              let list = List.filter ( fun f -> f.file_state = FileQueued ) filelist in
              DriverInteractive.display_active_file_list buf o list;
              ""
          | ["paused"] ->
              let list = List.filter ( fun f -> f.file_state = FilePaused ) filelist in
              DriverInteractive.display_active_file_list buf o list;
              ""
          | ["downloading"] ->
              let list = List.filter ( fun f -> f.file_state = FileDownloading ) filelist in
              DriverInteractive.display_file_list buf o list;
              ""
          | [arg] ->
            let num = int_of_string arg in
            if o.conn_output = HTML then
              begin
                if use_html_mods o then
                  Printf.bprintf buf "\\<div class=\\\"sourcesTable al\\\"\\>\\<table cellspacing=0 cellpadding=0\\>
				\\<tr\\>\\<td\\>
				\\<table cellspacing=0 cellpadding=0 width=100%%\\>\\<tr\\>
				\\<td nowrap class=\\\"fbig\\\"\\>\\<a href=\\\"files\\\"\\>Display all files\\</a\\>\\</td\\>
				\\<td nowrap class=\\\"fbig\\\"\\>\\<a href=\\\"submit?q=verify_chunks+%d\\\"\\>Verify chunks\\</a\\>\\</td\\>
				\\<td nowrap class=\\\"fbig\\\"\\>\\<a href=\\\"preview_download?q=%d\\\"\\>Preview\\</a\\>\\</td\\>
				\\<td nowrap class=\\\"fbig pr\\\"\\>\\<a href=\\\"javascript:window.location.reload()\\\"\\>Reload\\</a\\>\\</td\\>
				\\<td class=downloaded width=100%%\\>\\</td\\>
				\\</tr\\>\\</table\\>
				\\</td\\>\\</tr\\>
				\\<tr\\>\\<td\\>" num num
                else begin
                    Printf.bprintf  buf "\\<a href=\\\"files\\\"\\>Display all files\\</a\\>  ";
                    Printf.bprintf  buf "\\<a href=\\\"submit?q=verify_chunks+%d\\\"\\>Verify chunks\\</a\\>  " num;
                    Printf.bprintf  buf "\\<a href=\\\"submit?q=preview+%d\\\"\\>Preview\\</a\\> \n " num;
                  end
              end;
            List.iter
              (fun file -> if (as_file_impl file).impl_file_num = num then
                  CommonFile.file_print file o)
            list;
            List.iter
              (fun file -> if (as_file_impl file).impl_file_num = num then
                  CommonFile.file_print file o)
            !!done_files;
            ""
        | _ ->
            DriverInteractive.display_file_list buf o filelist;
            ""
    ), "[<num>|queued|paused|downloading] :\t$bview file info for download <num>, or lists of queued, paused or downloading files, or all downloads if no argument given$n";

    "preview", Arg_one (fun arg o ->

        let num = int_of_string arg in
        let file = file_find num in
        file_preview file;
        _s "done"
    ), "<file number> :\t\t\tstart previewer for file <file number>";

    "rename", Arg_two (fun arg new_name o ->
        let num = int_of_string arg in
        try
          let file = file_find num in
          set_file_best_name file new_name "" 0;
          Printf.sprintf (_b "Download %d renamed to %s") num (file_best_name file)
        with e -> Printf.sprintf (_b "No file number %d, error %s") num (Printexc2.to_string e)
    ), "<num> \"<new name>\" :\t\tchange name of download <num> to <new name>";

    "filenames_variability", Arg_none (fun o ->
      let list = List2.tail_map file_info
	(user2_filter_files !!files o.conn_user.ui_user_name) in
      DriverInteractive.filenames_variability o list;
      _s "done"
    ), ":\t\t\ttell which files have several very different names";

    "dllink", Arg_multiple (fun args o ->
        let url = String2.unsplit args ' ' in
        dllink_parse (o.conn_output = HTML) url o.conn_user.ui_user_name
        ), "<link> :\t\t\t\tdownload ed2k, sig2dat, torrent or other link";

    "dllinks", Arg_one (fun arg o ->
	let result = Buffer.create 100 in
        let file = File.to_string arg in
        let lines = String2.split_simplify file '\n' in
        List.iter (fun line ->
	  Buffer.add_string result (dllink_parse (o.conn_output = HTML) line o.conn_user.ui_user_name);
	  Buffer.add_string result (if o.conn_output = HTML then "\\<P\\>" else "\n")
        ) lines;
        (Buffer.contents result)
    ), "<file> :\t\t\tdownload all the links contained in the file";

  ]

(*************************************************************************)
(*                                                                       *)
(*                         Driver/Users                                  *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Users" [

    "useradd", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
	let add_new_user user pass_string =
          if user2_is_admin o.conn_user.ui_user_name
	    || o.conn_user.ui_user_name = (find_ui_user user).ui_user_name then
	    try
	      user2_user_set_password user pass_string;
	      print_command_result o buf (Printf.sprintf "Password of user %s changed" user)
            with Not_found ->
	      user2_user_add user (Md4.string pass_string) ();
	      print_command_result o buf (Printf.sprintf "User %s added with default values" user)
          else
	    print_command_result o buf "You are not allowed to add users"
	in begin
        match args with
	  user :: pass_string :: _ ->
	    add_new_user user pass_string;
	| _ -> print_command_result o buf "Wrong syntax: use 'useradd user pass'"
	end;
	_s ""
    ), "<user> <passwd> :\t\tadd new mldonkey user/change user password";

    "userdel", Arg_one (fun user o ->
        let buf = o.conn_buf in
        if user <> o.conn_user.ui_user_name then
          if user2_is_admin o.conn_user.ui_user_name then
	    if user = admin_user then
	      print_command_result o buf "User 'admin' can not be removed"
	    else
	      try
	        let n = user2_user_dls_count user in if n <> 0 then raise (User_has_downloads n);
	        ignore (user2_user_find user);
	        ignore (user2_user_remove user);
                print_command_result o buf (Printf.sprintf "User %s removed" user)
              with
	        Not_found -> print_command_result o buf (Printf.sprintf "User %s does not exist" user)
	      | User_has_downloads n -> print_command_result o buf
		    (Printf.sprintf "User %s has %d downloads, can not delete" user n)
          else
            print_command_result o buf "You are not allowed to remove users"
        else
          print_command_result o buf "You can not remove yourself";
	_s ""
    ), "<user> :\t\t\tremove a mldonkey user";

    "passwd", Arg_one (fun passwd o ->
        let buf = o.conn_buf in
	let user = o.conn_user.ui_user_name in
	begin
	  try
	    user2_user_set_password user passwd;
	    print_command_result o buf (Printf.sprintf "Password of user %s changed" user)
	  with Not_found -> print_command_result o buf (Printf.sprintf "User %s does not exist" user)
	end;
	_s ""
    ), "<passwd> :\t\tchange own password";

    "usermail", Arg_two (fun user mail o ->
        let buf = o.conn_buf in
        if user2_is_admin o.conn_user.ui_user_name
	  || o.conn_user.ui_user_name = (find_ui_user user).ui_user_name then
	  begin
	    try
	      user2_user_set_mail user mail;
	      print_command_result o buf (Printf.sprintf "User %s has new mail %s" user mail)
	    with Not_found -> print_command_result o buf (Printf.sprintf "User %s does not exist" user)
	  end
        else print_command_result o buf "You are not allowed to change mail addresses";
	_s ""
    ), "<user> <mail> :\t\tchange user mail address";

    "userdls", Arg_two (fun user dls o ->
        let buf = o.conn_buf in
        if user2_is_admin o.conn_user.ui_user_name
	  || o.conn_user.ui_user_name = (find_ui_user user).ui_user_name then
	  begin
	    try
	      user2_user_set_dls user (int_of_string dls);
	      print_command_result o buf (Printf.sprintf "User %s has now %s downloads allowed" user (user2_print_user_dls user))
	    with Not_found -> print_command_result o buf (Printf.sprintf "User %s does not exist" user)
	  end
        else print_command_result o buf "You are not allowed to change this value";
	_s ""
    ), "<user> <num> :\t\tchange number of allowed concurrent downloads";

    "usercommit", Arg_two (fun user dir o ->
        let buf = o.conn_buf in
        if user2_is_admin o.conn_user.ui_user_name
	  || o.conn_user.ui_user_name = (find_ui_user user).ui_user_name then
	  begin
	    try
	      user2_user_set_commit_dir user dir;
	      print_command_result o buf (Printf.sprintf "User %s has new commit dir %s" user (user2_print_user_commit_dir user))
	    with Not_found -> print_command_result o buf (Printf.sprintf "User %s does not exist" user)
	  end
        else print_command_result o buf "You are not allowed to change this value";
	_s ""
    ), "<user> <dir> :\t\tchange user specific commit directory";

    "groupadd", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
	let add_new_group group admin mail =
          if user2_is_admin o.conn_user.ui_user_name then
	    if user2_group_exists group then
	      print_command_result o buf (Printf.sprintf "Group %s already exists, use groupmod for updates" group)
	    else
	      begin
	        user2_group_add group ?mail:(Some mail) ?admin:(Some admin) ();
	        print_command_result o buf (Printf.sprintf "Group %s added" group)
	      end
          else
	    print_command_result o buf "You are not allowed to add group"
	in begin
        match args with
	  group :: admin :: mail :: _ ->
	    let a =
	      try
		bool_of_string admin
	      with _ -> false
	    in
	    add_new_group group a mail
	| group :: admin :: _ ->
	    let a =
	      try
		bool_of_string admin
	      with _ -> false
	    in
	    add_new_group group a ""
	| _ -> print_command_result o buf "Wrong syntax: use 'groupadd group true|false'"
	end;
	_s ""
    ), "<group> <admin: true | false> [<mail>] :\t\tadd new mldonkey group";

(* This does nothing, why is it here?
    "groupdel", Arg_one (fun group o ->
        let buf = o.conn_buf in
(*        if user2_is_admin o.conn_user.ui_user_name then _s ""
        else
          print_command_result o buf "You are not allowed to remove users"; *)
	_s ""
    ), "<group> :\t\t\tremove an unused mldonkey group";
*)

    "users", Arg_none (fun o ->
        let buf = o.conn_buf in
        if user2_is_admin o.conn_user.ui_user_name then begin

        if use_html_mods o then begin
            Printf.bprintf buf "\\<div class=\\\"shares\\\"\\>\\<table class=main cellspacing=0 cellpadding=0\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap class=\\\"fbig pr\\\"\\>\\<a onclick=\\\"javascript: {
                   var getdir = prompt('Input: <user> <pass>','user pass')
                   var reg = new RegExp (' ', 'gi') ;
                   var outstr = getdir.replace(reg, '+');
                   parent.fstatus.location.href='submit?q=useradd+' + outstr;
                   setTimeout('window.location.reload()',1000);
                    }\\\"\\>Add user\\</a\\>
\\</td\\>\\</tr\\>\\</table\\>\\</td\\>\\</tr\\>\\<tr\\>\\<td\\>";

            html_mods_table_header buf "sharesTable" "shares" [
              ( "0", "srh ac", "Click to remove user", "Remove" ) ;
              ( "0", "srh", "Username", "User" ) ;
              ( "0", "srh ac", "Admin", "Admin" ) ;
              ( "0", "srh", "Member of groups", "Groups" ) ;
              ( "0", "srh", "Default group", "Default group" ) ;
              ( "0", "srh", "Mail address", "Email" ) ;
              ( "0", "srh", "Commit dir", "Commit dir" ) ;
              ( "0", "srh ar", "Download quota", "Max DLs" ) ;
              ( "0", "srh ar", "Download count", "DLs" ) ];

            let counter = ref 0 in
            user2_user_iter (fun user ->
                incr counter;
		let u_dls = user2_user_dls_count user.user_name in
                Printf.bprintf buf "\\<tr class=\\\"%s\\\"\\>"
                (if !counter mod 2 == 0 then "dl-1" else "dl-2");
		if user.user_name <> admin_user && (u_dls = 0) then Printf.bprintf buf "
        \\<td title=\\\"Click to remove user\\\"
        onMouseOver=\\\"mOvr(this);\\\"
        onMouseOut=\\\"mOut(this);\\\"
        onClick=\\\'javascript:{
        parent.fstatus.location.href=\\\"submit?q=userdel+\\\\\\\"%s\\\\\\\"\\\";
        setTimeout(\\\"window.location.reload()\\\",1000);}'
        class=\\\"srb\\\"\\>Remove\\</td\\>" user.user_name
		else Printf.bprintf buf "
        \\<td title=\\\"\\\"
        class=\\\"srb\\\"\\>------\\</td\\>";
		Printf.bprintf buf
		  "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" user.user_name;
		Printf.bprintf buf
		  "\\<td class=\\\"sr ac\\\"\\>%b\\</td\\>" (user2_is_admin user.user_name);
		Printf.bprintf buf
		  "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" (user2_print_user_groups user.user_name);
		Printf.bprintf buf
		  "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" (user2_print_user_default_group user.user_name);
		Printf.bprintf buf
		  "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" (user2_print_user_mail user.user_name);
		Printf.bprintf buf
		  "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" (user2_print_user_commit_dir user.user_name);
		Printf.bprintf buf
		  "\\<td class=\\\"sr ar\\\"\\>%s\\</td\\>" (user2_print_user_dls user.user_name);
		Printf.bprintf buf
		  "\\<td class=\\\"sr ar\\\"\\>%d\\</td\\>" u_dls
            );
            Printf.bprintf buf "\\</table\\>\\</td\\>\\<tr\\>\\</table\\>\\</div\\>\\<P\\>";
	    print_option_help o userlist;
            Printf.bprintf buf "\\<P\\>";

            Printf.bprintf buf "\\<div class=\\\"shares\\\"\\>\\<table class=main cellspacing=0 cellpadding=0\\>
\\<tr\\>\\<td\\>
\\<table cellspacing=0 cellpadding=0  width=100%%\\>\\<tr\\>
\\<td class=downloaded width=100%%\\>\\</td\\>
\\<td nowrap class=\\\"fbig pr\\\"\\>\\<a onclick=\\\"javascript: {
                   var getdir = prompt('Input: <group> <admin: true|false> [<mail>]','group true')
                   var reg = new RegExp (' ', 'gi') ;
                   var outstr = getdir.replace(reg, '+');
                   parent.fstatus.location.href='submit?q=groupadd+' + outstr;
                   setTimeout('window.location.reload()',1000);
                    }\\\"\\>Add group\\</a\\>
\\</td\\>\\</tr\\>\\</table\\>\\</td\\>\\</tr\\>\\<tr\\>\\<td\\>";

            html_mods_table_header buf "sharesTable" "shares" [
              ( "0", "srh ac", "Click to remove group", "Remove" ) ;
              ( "0", "srh", "Groupname", "Group" ) ;
              ( "0", "srh ac", "Admin group", "Admin" ) ;
              ( "0", "srh", "Mail address", "Email" ) ;
              ( "0", "srh ar", "Download count", "DLs" ) ];

            let counter = ref 0 in
            user2_group_iter (fun group ->
                incr counter;
		let g_dls = user2_group_dls_count group.group_name in
                Printf.bprintf buf "\\<tr class=\\\"%s\\\"\\>"
                (if !counter mod 2 == 0 then "dl-1" else "dl-2");
		if g_dls = 0 then Printf.bprintf buf "
        \\<td title=\\\"Click to remove group\\\"
        onMouseOver=\\\"mOvr(this);\\\"
        onMouseOut=\\\"mOut(this);\\\"
        onClick=\\\'javascript:{
        parent.fstatus.location.href=\\\"submit?q=groupdel+\\\\\\\"%s\\\\\\\"\\\";
        setTimeout(\\\"window.location.reload()\\\",1000);}'
        class=\\\"srb\\\"\\>Remove\\</td\\>" group.group_name
		else Printf.bprintf buf "
        \\<td title=\\\"\\\"
        class=\\\"srb\\\"\\>------\\</td\\>";
		Printf.bprintf buf
		  "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" group.group_name;
		Printf.bprintf buf
		  "\\<td class=\\\"sr ac\\\"\\>%b\\</td\\>" group.group_admin;
		Printf.bprintf buf
		  "\\<td class=\\\"sr\\\"\\>%s\\</td\\>" group.group_mail;
		Printf.bprintf buf
		  "\\<td class=\\\"sr ar\\\"\\>%d\\</td\\>" g_dls
            );
            Printf.bprintf buf "\\</table\\>\\</td\\>\\<tr\\>\\</table\\>\\</div\\>\\<P\\>";
	    print_option_help o grouplist;
            Printf.bprintf buf "\\<P\\>";

            Buffer.add_string buf "\\<div class=\\\"cs\\\"\\>";
            html_mods_table_header buf "helpTable" "results" [];
            Buffer.add_string buf "\\<tr\\>";
            html_mods_td buf [
              ("", "srh", "");
              ("", "srh", "Commands to manipulate user data");
              ("", "srh", ""); ];
            Buffer.add_string buf "\\</tr\\>";
            html_mods_cntr_init ();
            let list = Hashtbl2.to_list2 commands_by_kind in
            let list = List.sort (fun (s1,_) (s2,_) -> compare s1 s2) list in
            List.iter (fun (s,list) ->
	      if s = "Driver/Users" then
              let list = List.sort (fun (s1,_) (s2,_) -> compare s1 s2) !list in
              List.iter (fun (cmd, help) ->
                Printf.bprintf buf "\\<tr class=\\\"dl-%d\\\"\\>" (html_mods_cntr ());
                html_mods_td buf [
                  ("", "sr", "\\<a href=\\\"submit?q=" ^ cmd ^
                    "\\\"\\>" ^ cmd ^ "\\</a\\>");
                  ("", "srw", Str.global_replace (Str.regexp "\n") "\\<br\\>" help);
                  ("", "sr", "\\<a href=\\\"http://mldonkey.sourceforge.net/" ^ (String2.upp_initial cmd) ^
                    "\\\"\\>wiki\\</a\\>"); ];
                Printf.bprintf buf "\\</tr\\>\n"
              ) list
          ) list
          end
        else
          begin
            Printf.bprintf buf "Users:\n";
            user2_user_iter (fun user ->
                Printf.bprintf buf "  %s\n"
                user.user_name);
            Printf.bprintf buf "\nGroup:\n";
            user2_group_iter (fun group ->
                Printf.bprintf buf "  %s\n"
                group.group_name);
          end;
	end else print_command_result o buf "You are not allowed to list users";
          _s ""
    ), "\t\t\t\t\tprint users";

    "whoami", Arg_none (fun o ->
	print_command_result o o.conn_buf o.conn_user.ui_user_name;
        _s ""
    ), "\t\t\t\t\tprint logged-in user name";

    "chgrp", Arg_two (fun group filenum o ->
        let num = int_of_string filenum in
        try
          let file = file_find num in
          if set_file_group_safe file o.conn_user.ui_user_name (if (String.lowercase group) = "none" then None else Some group) then
            Printf.sprintf (_b "Changed group of download %d to %s") num group
	  else
            Printf.sprintf (_b "Could not change group of download %d to %s") num group
        with e -> Printf.sprintf (_b "No file number %d, error %s") num (Printexc2.to_string e)
    ), "<group> \"<num>\" :\t\tchange group of download <num> to <group>, group = none for private file";

    "chown", Arg_two (fun new_owner filenum o ->
        let num = int_of_string filenum in
        try
          let file = file_find num in
          if set_file_owner_safe file o.conn_user.ui_user_name new_owner then
            Printf.sprintf (_b "Changed owner of download %d to %s") num new_owner
	  else
            Printf.sprintf (_b "Could not change owner of download %d to %s") num new_owner
        with e -> Printf.sprintf (_b "No file number %d, error %s") num (Printexc2.to_string e)
    ), "<user> \"<num>\" :\t\tchange owner of download <num> to <user>";

  ]


(*************************************************************************)
(*                                                                       *)
(*                         Driver/Xpert                                  *)
(*                                                                       *)
(*************************************************************************)

let _ =
  register_commands "Driver/Xpert"
    [

    "reload_messages", Arg_none (fun o ->
        CommonMessages.load_message_file ();
        "\\<script type=\\\"text/javascript\\\"\\>top.window.location.reload();\\</script\\>"
    ), ":\t\t\treload messages file";

    "log", Arg_none (fun o ->
        let buf = o.conn_buf in
        log_to_buffer buf;
        _s "------------- End of log"
    ), ":\t\t\t\t\tdump current log state to console";

    "ansi", Arg_one (fun arg o ->
        let b = bool_of_string arg in
        if b then begin
            o.conn_output <- ANSI;
          end else
          o.conn_output <- TEXT;
        _s "$rdone$n"
    ), ":\t\t\t\t\ttoggle ansi terminal (devel)";

    "term", Arg_two (fun w h o ->
        let w = int_of_string w in
        let h = int_of_string h in
        o.conn_width <- w;
        o.conn_height <- h;
        "set"),
    "<width> <height> :\t\t\tset terminal width and height (devel)";

    "stdout", Arg_one (fun arg o ->
	if (bool_of_string arg) then
	  begin
	    lprintf_nl "Enable logging to stdout...";
	    log_to_file stdout;
	    lprintf_nl "Logging to stdout..."
	  end
	else
	  begin
	    lprintf_nl "Disable logging to stdout...";
	    close_log ();
	    if !!log_file <> "" then
	      begin
                let oc = open_out_gen [Open_creat; Open_wronly; Open_append] 0o644 !!log_file in
                  log_to_file oc;
                  lprintf_nl "Reopened %s" !!log_file
	      end
	  end;
        Printf.sprintf (_b "log to stdout %s")
        (if (bool_of_string arg) then _s "enabled" else _s "disabled")
    ), "<true|false> :\t\t\treactivate log to stdout";

    "debug_client", Arg_multiple (fun args o ->
        List.iter (fun arg ->
            let num = int_of_string arg in
            debug_clients := Intset.add num !debug_clients;
            (try let c = client_find num in client_debug c true with _ -> ())
        ) args;
        _s "done"
    ), "<client nums> :\t\tdebug message in communications with these clients";

    "debug_file", Arg_multiple (fun args o ->
        List.iter (fun arg ->
            let num = int_of_string arg in
            let file = file_find num in
            Printf.bprintf o.conn_buf
              "File %d:\n%s" num
              (file_debug file);
        ) args;
        _s "done"
    ), "<client nums> :\t\tdebug file state";

    "clear_debug", Arg_none (fun o ->

        Intset.iter (fun num ->
            try let c = client_find num in
              client_debug c false with _ -> ()
        ) !debug_clients;
        debug_clients := Intset.empty;
        _s "done"
    ), ":\t\t\t\tclear the table of clients being debugged";

    "merge", Arg_two (fun f1 f2 o ->
        let file1 = file_find (int_of_string f1) in
        let file2 = file_find (int_of_string f2) in
        CommonSwarming.merge file1 file2;
        "The two files are now merged"
    ), "<num1> <num2> :\t\t\ttry to swarm downloads from file <num2> (secondary) to file <num1> (primary)";

    "open_log", Arg_none (fun o ->
        if !!log_file <> "" then
	  begin
	    let log = !!log_file in
	      CommonOptions.log_file =:= log;
            Printf.sprintf "opened logfile %s" !!log_file
	  end
	else
          Printf.sprintf "works only if log_file is set"
    ), ":\t\t\t\tenable logging to file";

    "close_log", Arg_none (fun o ->
  lprintf_nl "Stopped logging...";
        close_log ();
        _s "log stopped"
    ), ":\t\t\t\tclose logging to file";

     "clear_log", Arg_none (fun o ->
        if !!log_file <> "" then
          begin
            close_log ();
            let oc = open_out_gen [Open_creat; Open_wronly; Open_trunc] 0o644 !!log_file in
              log_to_file oc;
              lprintf_nl "Cleared %s" !!log_file;
              Printf.sprintf "Logfile %s cleared" !!log_file
          end
        else
          Printf.sprintf "works only if log_file is set"
     ), ":\t\t\t\tclear log_file";

    "html_mods", Arg_none (fun o ->
        if !!html_mods then
          begin
            html_mods =:= false;
            commands_frame_height =:= 140;
          end
        else
          begin
            html_mods =:= true;
            html_mods_style =:= 0;
            commands_frame_height =:= CommonMessages.styles.(!!html_mods_style).frame_height;
            use_html_frames =:= true;
            CommonMessages.colour_changer() ;
          end;

	"\\<script type='text/javascript'\\>top.window.location.replace('/');\\</script\\>"
    ), ":\t\t\t\ttoggle html_mods";


    "html_mods_style", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        if args = [] then begin
            Array.iteri (fun i style ->
                Printf.bprintf buf "%d: %s\n" i style.style_name;
            ) CommonMessages.styles;
            ""
          end
        else begin
            html_mods =:= true;
            use_html_frames =:= true;
            html_mods_theme =:= "";
            let num = int_of_string (List.hd args) in

	    html_mods_style =:=
	      if num >= 0 && num < Array.length CommonMessages.styles then
                num else 0;
            commands_frame_height =:= CommonMessages.styles.(!!html_mods_style).frame_height;
            CommonMessages.colour_changer ();
	    "\\<script type='text/javascript'\\>top.window.location.replace('/');\\</script\\>"
          end

    ), ":\t\t\tselect html_mods_style <#>";

    "rss", Arg_none (fun o ->
        let buf = o.conn_buf in
        let module CW = CommonWeb in
        Hashtbl.iter (fun url feed ->
            let r = feed.CW.rss_value in
            if o.conn_output = HTML then begin
                Printf.bprintf buf "\\</pre\\>\\<div class=\\\"cs\\\"\\>";
                html_mods_table_header buf "rssTable" "results" [
                   ( "0", "sr", "Content", "Content" ) ;
                   ( "0", "sr", "MLDonkey Download", "Download" ) ];
                Printf.bprintf buf "\\<tr\\>";
                html_mods_td buf [
                  (r.Rss.ch_title ^ " : " ^ url ^ (Printf.sprintf ", loaded %d hours ago" (((last_time ()) - feed.CW.rss_date) / 3600)), "srh", r.Rss.ch_title);
                  ("", "srh", "") ];
                Printf.bprintf buf "\\</tr\\>"
              end
            else begin
                Printf.bprintf buf "%s:\n" url;
                Printf.bprintf buf "   loaded %d hours ago\n" (feed.CW.rss_date / 3600);
                Printf.bprintf buf "   title: %s\n" r.Rss.ch_title;
            end;
            html_mods_cntr_init ();
            List.iter (fun item ->
                match item.Rss.item_title, item.Rss.item_link with
                  None, _
                | _, None -> ()
                | Some title, Some link ->
                  if o.conn_output = HTML then begin
                      Printf.bprintf buf "\\<tr class=\\\"dl-%d\\\"\\>" (html_mods_cntr ());
                      html_mods_td buf [
                        (title, "sr", "\\<a href=\\\"" ^ link ^ "\\\"\\>" ^ title ^ "\\</a\\>");
                        (title, "sr", 
                          "\\<a href=\\\"submit?q=dllink+"
                          ^ (Url.encode link)
                          ^ "\\\"\\ title=\\\"\\dllink\\\"\\>dllink\\</a\\>"
                          ^
                          " \\<a href=\\\"submit?q=http+"
                          ^ (Url.encode link)
                          ^ "\\\"\\ title=\\\"\\http\\\"\\>http\\</a\\>"
                          ^
                          " \\<a href=\\\"submit?q=startbt+"
                          ^ (Url.encode link)
                          ^ "\\\"\\ title=\\\"\\startbt\\\"\\>startbt\\</a\\>"
                        )
		      ];
                      Printf.bprintf buf "\\</tr\\>"
                    end
                  else begin
                      Printf.bprintf buf "     %s\n" title;
                      Printf.bprintf buf "       > %s\n" link
                    end
            ) r.Rss.ch_items;
            if o.conn_output = HTML then
                Printf.bprintf buf "\\</table\\>\\</div\\>\\</div\\>\\<pre\\>";
        ) CW.rss_feeds;
        ""


    ), ":\t\t\t\t\tprint RSS feeds";

    "html_theme", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
        if args = [] then begin
            Printf.bprintf buf "Usage: html_theme <theme name>\n";
            Printf.bprintf buf "To use internal theme: html_theme \\\"\\\"\n";
            Printf.bprintf buf "Current theme: %s\n\n" !!html_mods_theme;
            Printf.bprintf buf "Available themes:\n";
            if Sys.file_exists html_themes_dir then begin
                let list = Unix2.list_directory html_themes_dir in
                List.iter (fun d ->
                    if Unix2.is_directory (Filename.concat html_themes_dir d) then
                      Printf.bprintf buf "%s\n" d;
                ) (List.sort (fun d1 d2 -> compare d1 d2) list);
              end;
            ""
          end
        else begin
(* html_mods =:= true;
            use_html_frames =:= true; *)
            html_mods_theme =:= List.hd args;
            "\\<script type=\\\"text/javascript\\\"\\>top.window.location.reload();\\</script\\>"
          end

    ), "<theme> :\t\t\tselect html_theme";

    "mem_stats", Arg_multiple (fun args o ->
        let buf = o.conn_buf in
	let level = match args with
	  [] -> 0
	| n :: _ -> int_of_string n in
        Heap.print_memstats level buf (use_html_mods o);
        ""
    ), ":\t\t\t\tprint memory stats [<verbosity #num>]";

    "close_all_sockets", Arg_none (fun o ->
        BasicSocket.close_all ();
        _s "All sockets closed"
    ), ":\t\t\tclose all opened sockets";

    "use_poll", Arg_one (fun arg o ->
        let b = bool_of_string arg in
        BasicSocket.use_poll b;
        Printf.sprintf "poll: %s" (string_of_bool b)
    ), "<bool> :\t\t\tuse poll instead of select";

    "close_fds", Arg_none (fun o ->
        Unix32.close_all ();
        let buf = o.conn_buf in
        if o.conn_output = HTML then
          html_mods_table_one_row buf "serversTable" "servers" [
            ("", "srh", "All files closed"); ]
        else
          Printf.bprintf buf "All files closed";
        ""
    ), ":\t\t\t\tclose all files (use to free space on disk after remove)";

    "debug_socks", Arg_none (fun o ->
        BasicSocket.print_sockets o.conn_buf;
        _s "done"
    ), ":\t\t\t\tfor debugging only";

    "block_list", Arg_none (fun o ->
      let buf = o.conn_buf in
      if o.conn_output = HTML then
	List.iter (fun (tablename, l) ->
	  html_mods_cntr_init ();
	  html_mods_table_header buf tablename "servers" [
	    ( "0", "srh ac br", "Description (" ^ tablename ^ ")", "Description (" ^ tablename ^ ")") ;
	    ( "0", "srh ac br", "Hits", "Hits") ;
	    ( "0", "srh ac", "Range", "Range")];
          let nhits, nranges = 
	    Ip_set.bl_fold_left (fun br (nhits, nranges) ->
	      if br.Ip_set.blocking_hits > 0 then begin
		Printf.bprintf buf "\\<tr class=\\\"dl-%d\\\"\\>"
		  (html_mods_cntr ());
		html_mods_td buf [
		  ("Description", "sr br", br.Ip_set.blocking_description);
		  ("Hits", "sr ar br", string_of_int br.Ip_set.blocking_hits);
		  ("Range", "sr", Printf.sprintf "%s - %s"
		    (Ip.to_string br.Ip_set.blocking_begin)
		    (Ip.to_string br.Ip_set.blocking_end))];
		Printf.bprintf buf "\\</tr\\>";
	      end;
	      (nhits + br.Ip_set.blocking_hits, nranges + 1)
	    ) (0, 0) l in
	  Printf.bprintf buf "\\<tr class=\\\"dl-%d\\\"\\>"
	    (html_mods_cntr ());
	  if nranges > 0 then
	  html_mods_td buf [
	    ("Total ranges", "sr br total", ("Total ranges " ^ string_of_int nranges));
	    ("Hits", "sr ar br total", Printf.sprintf "%s" (string_of_int nhits));
	    ("", "sr br total", "")]
	  else begin
	  html_mods_td buf [
	    ("no " ^ tablename ^ " loaded", "sr", "no " ^ tablename ^ " loaded");
	    ("", "sr", "");
	    ("", "sr", "")];
	  end;
	  Printf.bprintf buf "\\</tr\\>\\</table\\>\\<P\\>";
	) [
	  ("Web blocking list", !CommonBlocking.web_ip_blocking_list); 
	  ("Local blocking list", !CommonBlocking.ip_blocking_list)]
      else begin
	Printf.bprintf buf "Web blocking list\n";
	Ip_set.print_list buf !CommonBlocking.web_ip_blocking_list;
	Printf.bprintf buf "Local blocking list\n";
	Ip_set.print_list buf !CommonBlocking.ip_blocking_list;
      end;
      _s ""
    ), ":\t\t\t\tdisplay the list of blocked IP ranges that were hit";

    "block_test", Arg_one (fun arg o ->
      let ip = Ip.of_string arg in
      _s (match !Ip.banned ip with
          None -> "Not blocked"
        | Some reason ->
          Printf.sprintf "Blocked, %s\n" reason)
    ), "<ip> :\t\t\tcheck whether an IP is blocked";
  ]
