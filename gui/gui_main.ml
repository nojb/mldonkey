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

open Gui_global
module O = Gui_options
module M = Gui_messages
module Com = Gui_com
module G = Gui_global
module Mi = Gui_misc

(*module Gui_rooms = Gui_rooms2*)
  
let (!!) = Options.(!!)

let _ = GMain.Main.init ()

let _ = 
  (try Options.load O.mldonkey_gui_ini with
      e ->
        Printf.printf "Exception %s in load options" (Printexc.to_string e);
        print_newline ();
  );
  let args = Options.simple_args O.mldonkey_gui_ini in
  Arg.parse args (Arg.usage args)  "mldonkey_gui: the GUI to use with mldonkey"

(* Check bindings *)
let _ = 
  if !!O.keymap_global = [] then
    (
     let a = O.add_binding O.keymap_global in
     a "A-s" M.a_page_servers;
     a "A-d" M.a_page_downloads;
     a "A-f" M.a_page_friends;
     a "A-q" M.a_page_queries;
     a "A-r" M.a_page_results;
     a "A-m" M.a_page_rooms ;
     a "A-u" M.a_page_uploads;
     a "A-o" M.a_page_options;
     a "A-c" M.a_page_console;
     a "A-h" M.a_page_help;
     a "A-Left" M.a_previous_page;
     a "A-Right" M.a_next_page;
     a "C-r" M.a_reconnect;
     a "C-e" M.a_exit ;
    );
  if !!O.keymap_servers = [] then
    (
     let a = O.add_binding O.keymap_servers in
     a "C-c" M.a_connect;
     a "C-m" M.a_connect_more;
     a "C-a" M.a_select_all;
    );
  if !!O.keymap_downloads = [] then
    (
     let a = O.add_binding O.keymap_downloads in
     a "C-c" M.a_cancel_download;
     a "CS-s" M.a_save_all_files;
     a "C-s" M.a_menu_save_file;
     a "C-a" M.a_select_all;
    );
  if !!O.keymap_friends = [] then
    (
     let a = O.add_binding O.keymap_friends in
     a "C-d" M.a_download_selection;
     a "C-x" M.a_remove_friend;
     a "C-a" M.a_select_all;
    );
  if !!O.keymap_queries = [] then
    (
     let a = O.add_binding O.keymap_queries in
     ()
    );
  if !!O.keymap_results = [] then
    (
     let a = O.add_binding O.keymap_results in
     ()
    );
  if !!O.keymap_console = [] then
    (
     let a = O.add_binding O.keymap_console in
     ()
    )

(** {2 Handling core messages} *)

open CommonTypes
open GuiTypes
open GuiProto
  
let canon_client gui c =
  let box_file_locs = gui#tab_downloads#box_locations in 
  let box_friends = gui#tab_friends#box_friends in
  let c = 
    try
      let cc = Hashtbl.find G.locations c.client_num in
      
      let is_in_locations =
        try
          ignore (box_file_locs#find_client c.client_num);
          true
        with _ -> false 
      in
      if is_in_locations then
        gui#tab_downloads#h_update_location c;
      
      if c.client_files <> None then  cc.client_files <- c.client_files;
      cc.client_state <- c.client_state;
      begin
        if c.client_type <> cc.client_type then begin
            match c.client_type, cc.client_type with
            | NormalClient, _ ->
                box_friends#h_remove_friend c.client_num
            | _  ->
                box_friends#h_update_friend cc
          end
      end;
      
      cc.client_type <- c.client_type;
      cc.client_rating <- c.client_rating;
      cc.client_name <- c.client_name;
      
      cc.client_kind <- c.client_kind;
      cc.client_tags <- c.client_tags;
      begin
        match c.client_type with
          NormalClient -> ()
        | _ -> box_friends#h_update_friend cc;
      end;
      
      cc
    with _ ->
(*        Printf.printf "Adding client %d" c.client_num; print_newline (); *)
        Hashtbl.add G.locations c.client_num c;
        begin
          match c.client_type with
            NormalClient -> ()
          | _ -> box_friends#h_update_friend c;
        end;
        c
  in
  c
  
let value_reader gui t sock =
  try
    match t with
    | Console text ->
        gui#tab_console#insert text
    
    | Network_info n ->
        begin
          try
            let nn = Hashtbl.find Gui_global.networks n.network_netnum
            in
            nn.net_enabled <- n.network_enabled;
            nn.net_menu_item#set_active n.network_enabled
          with _ ->
              let display_menu_item =
                GMenu.check_menu_item ~label: n.network_netname ~active:true
                ~packing:gui#menu_display#add ()
              in
              let network_menu_item =
                GMenu.check_menu_item ~label: n.network_netname 
                  ~active:n.network_enabled
                  ~packing:gui#menu_networks#add ()
              in
              let nn = {
                  net_num = n.network_netnum;
                  net_name = n.network_netname;
                  net_enabled = n.network_enabled;
                  net_menu_item = network_menu_item;
                  net_displayed = true;
                } in
              ignore (network_menu_item#connect#toggled ~callback:(fun _ ->
                    nn.net_enabled <- not nn.net_enabled;
                    Com.send (EnableNetwork (n.network_netnum, 
                        network_menu_item#active)
                    )));
              ignore (display_menu_item#connect#toggled ~callback:(fun _ ->
                    nn.net_displayed <- not nn.net_displayed;
                    networks_filtered := (if nn.net_displayed then
                        List2.removeq nn.net_num !networks_filtered
                      else nn.net_num :: !networks_filtered);
                    gui#tab_servers#h_server_filter_networks;
                    gui#tab_queries#h_search_filter_networks;
                ));
              Hashtbl.add Gui_global.networks n.network_netnum nn;
              ()
        end
    
    | Client_stats s ->
        gui#tab_uploads#wl_status#set_text
          (Printf.sprintf "Shared: %5d/%-12s   U/D bytes/s: %7d/%-7d" 
            s.nshared_files 
            (Gui_misc.size_of_int64 s.upload_counter)
          s.upload_rate
          s.download_rate
        )
    
    | CoreProtocol v -> 
        
        Gui_com.gui_protocol_used := min v GuiEncoding.best_gui_version;
        Printf.printf "Using protocol %d for communications" !Gui_com.gui_protocol_used;
        print_newline ();
        gui#label_connect_status#set_text M.connected;
        Com.send (Password (!!O.password))
    
    | Search_result (num,r) -> 
        begin try
            let r = Hashtbl.find G.results r in
            gui#tab_queries#h_search_result num r
          with _ -> 
              Printf.printf "Exception in Search_result %d %d" num r;
              print_newline ();
        end
    
    | Search_waiting (num,waiting) -> 
        gui#tab_queries#h_search_waiting num waiting
    
    | File_source (num, src) -> 
        gui#tab_downloads#h_file_location num src;
    
    | File_downloaded (num, downloaded, rate) ->
        gui#tab_downloads#h_file_downloaded num downloaded rate
    
    | File_availability (num, chunks, avail) ->
        gui#tab_downloads#h_file_availability num chunks avail;
    
    | File_info f ->
(*        Printf.printf "FILE INFO"; print_newline (); *)
        gui#tab_downloads#h_file_info f;
    
    | Server_info s ->
(*        Printf.printf "server info"; print_newline (); *)
        gui#tab_servers#h_server_info s
    
    | Server_state (key,state) ->
        gui#tab_servers#h_server_state key state
    
    | Server_busy (key,nusers, nfiles) ->
        gui#tab_servers#h_server_busy key nusers nfiles
    
    | Server_user (key, user) ->
(*        Printf.printf "server user %d %d" key user; print_newline (); *)
        if not (Hashtbl.mem G.users user) then begin
(*            Printf.printf "Unknown user %d" user; print_newline ();*)
            Gui_com.send (GetUser_info user);
          end else 
          begin
            gui#tab_servers#h_server_user key user
          end
    
    | Room_info room ->
(*        Printf.printf "Room info %d" room.room_num; print_newline (); *)
        gui#tab_rooms#room_info room
    
    | User_info user ->
        let user = try 
            let u = Hashtbl.find G.users user.user_num  in
            u.user_tags <- user.user_tags;
            u
          with Not_found ->
              Hashtbl.add G.users user.user_num user; 
              user
        in
(*        Printf.printf "user_info %s/%d" user.user_name user.user_server; print_newline (); *)
        gui#tab_servers#h_server_user user.user_server user.user_num;
        Gui_rooms.user_info user
    
    | Room_add_user (num, user_num) -> 
        
        begin try
            gui#tab_rooms#add_room_user num user_num
          with e ->
              Printf.printf "Exception in Room_user %d %d" num user_num;
              print_newline ();
        end
    
    | Room_remove_user (num, user_num) -> 
        
        begin try
            gui#tab_rooms#remove_room_user num user_num
          with e ->
              Printf.printf "Exception in Room_user %d %d" num user_num;
              print_newline ();
        end
    
    | Options_info list ->
(*        Printf.printf "Options_info"; print_newline ();*)
        let rec iter list =
          match list with
            [] -> ()
          | (name, value) :: tail ->
              (
                try
                  let reference = 
                    List.assoc name Gui_options.client_options_assocs 
                  in                  
                  reference := value;
                  Gui_config.add_option_value name reference
                with _ -> 
                    Gui_config.add_option_value name (ref value)
              );
              iter tail
        in
        iter list
    
    | Add_section_option (section, message, option, optype) ->
        let line = message, optype, option in
        (try
            let options = List.assoc section !client_sections in
            if not (List.mem line !options) then
              options := !options @ [line]
        with _ ->
            client_sections := !client_sections  @[section, ref [line]]
        )          
        
    | DefineSearches l ->
        gui#tab_queries#h_define_searches l
    
    | Client_state (num, state) ->
(*
	Printf.printf "Client_state" ; print_newline ();
*)
        (
          try
            let c = Hashtbl.find G.locations num in
            ignore (canon_client gui { c with client_state = state })
          with _ -> 
              Com.send (GetClient_info num)
        )
    
    | Client_friend (num, friend_kind) ->
        (
          try
            let c = Hashtbl.find G.locations num in
            ignore (canon_client gui { c with client_type = friend_kind });
          with _ -> 
              Com.send (GetClient_info num)
        )
    
    | Result_info r ->
        
        if not (Hashtbl.mem G.results r.result_num) then
          Hashtbl.add G.results r.result_num r
    
    | Client_file (num , dirname, file_num) ->
(* Here, the dirname is forgotten: it should be used to build a tree
  when possible... *)
        
        (
          try
            let file = Hashtbl.find G.results file_num in
            try
              let c = Hashtbl.find G.locations num in
              try
                let tree = match c.client_files with
                    None -> { file_tree_list = []; file_tree_name = "" }
                  | Some tree -> { tree with file_tree_list = tree.file_tree_list }
                in

                add_file tree dirname file;
                ignore (canon_client gui { c with client_files = Some tree })
                
              with _ ->
(*                  Printf.printf "File already there"; print_newline (); *)
                  ()
            with _ ->
(*                Printf.printf "Unknown client %d" num; print_newline (); *)
                Com.send (GetClient_info num);
          with _ ->  
(*              Printf.printf "Unknown file %d" file_num;
              print_newline (); *)
              ()
	)

    | Client_info c -> 
(*        Printf.printf "Client_info"; print_newline (); *)
        (
	 try
	   ignore (canon_client gui c) ;
	 with _ -> ()
	)
(* A VOIR : Ca sert � quoi le bouzin ci-dessous ?
ben, ca sert a mettre a jour la liste des locations affichees pour un
fichier selectionne. Si ca marche toujours dans ton interface, pas de
  probleme ...
        begin
          match !current_file with
            None -> ()
          | Some file ->
              let num = c.client_num in
              match file.file_more_info with
                None -> ()
              | Some fmi ->
                  if array_memq num fmi.file_known_locations ||
                    array_memq num fmi.file_indirect_locations then
                    let c = Hashtbl.find locations c.client_num in
                    if is_connected c.client_state then incr nclocations;
                    MyCList.update clist_file_locations c.client_num c
        end
*)


    | Room_message (_, PrivateMessage(num, mes))
    | Room_message (0, PublicMessage(num, mes))
    | MessageFromClient (num, mes) ->
	(
	 try
	   let c = Hashtbl.find G.locations num in
	   let d = gui#tab_friends#get_dialog c in
	   d#handle_message mes
	 with
	   Not_found ->
	     Printf.printf "Client %d not found in reader.MessageFromClient" num;
	     print_newline ()
        )    
        
    | Room_message (num, msg) ->
        begin try
            gui#tab_rooms#add_room_message num msg
          with e ->
              Printf.printf "Exception in Room_message %d" num;
              print_newline ();
        end

    | (DownloadedFiles _|DownloadFiles _|ConnectedServers _) -> assert false

    | Shared_file_info si ->
	gui#tab_uploads#h_shared_file_info si
    | Shared_file_upload (num,size,requests) ->
        gui#tab_uploads#h_shared_file_upload num size requests
    | Shared_file_unshared _ ->
        ()
  with e ->
      Printf.printf "Exception %s in reader" (Printexc.to_string e);
      print_newline ()

let main () =
  let gui = new Gui_window.window () in
  let w = gui#window in
  let quit () = 
    (try
        Gui_misc.save_gui_options gui;
        Gui_com.disconnect gui;
      with _ -> ());
    exit 0
  in
  Gui_config.update_toolbars_style gui;
  ignore (w#connect#destroy quit);

  (** menu actions *)
  ignore (gui#itemQuit#connect#activate w#destroy) ;
  ignore (gui#itemKill#connect#activate (fun () -> Com.send KillServer));
  ignore (gui#itemReconnect#connect#activate 
	    (fun () ->Com.reconnect gui (value_reader gui)));
  ignore (gui#itemDisconnect#connect#activate 
	    (fun () -> Com.disconnect gui));
  ignore (gui#itemServers#connect#activate (fun () -> gui#notebook#goto_page 0));
  ignore (gui#itemDownloads#connect#activate (fun () -> gui#notebook#goto_page 1));
  ignore (gui#itemFriends#connect#activate (fun () -> gui#notebook#goto_page 2));
  ignore (gui#itemSearches#connect#activate (fun () -> gui#notebook#goto_page 3));
  ignore (gui#itemResults#connect#activate (fun () -> gui#notebook#goto_page 4));
  ignore (gui#itemRooms#connect#activate (fun () -> gui#notebook#goto_page 5));
  ignore (gui#itemUploads#connect#activate (fun () -> gui#notebook#goto_page 6));
  ignore (gui#itemConsole#connect#activate (fun () -> gui#notebook#goto_page 7));
  ignore (gui#itemHelp#connect#activate (fun () -> gui#notebook#goto_page 8));

  ignore (gui#itemOptions#connect#activate (fun () -> Gui_config.edit_options gui));


  (** connection with core *)
  Com.reconnect gui (value_reader gui) ;
  
  let gtk_handler timer =
    while Glib.Main.pending () do
      ignore (Glib.Main.iteration false)
    done;
  in
    
  BasicSocket.add_infinite_timer 0.1 gtk_handler;
(*  BasicSocket.add_timer 2.0 update_sizes;*)
  let never_connected = ref true in
  BasicSocket.add_timer 1.0 (fun timer ->
      if !never_connected then 
        match !Com.connection with
          None ->
            BasicSocket.reactivate_timer timer;
            Com.reconnect gui (value_reader gui)
        | _ -> 
            never_connected := false
  );

  BasicSocket.loop ()
;;

main ()
