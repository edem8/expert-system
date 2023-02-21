%------------------------------------------------
% CVS history
%
% $Log: kwcgirun.pro,v $
% Revision 1.5  2001/12/17 20:02:24  mary
% Fixed bug for resubmitting CGI forms. Other minor fixes.
%
% Revision 1.4  2001/11/11 16:00:57  mary
% Removed acgi.pro from here as it is in each jig.
%
% Revision 1.3  2001/02/23 00:49:30  mary
% Fix cgi interface for Amzi 6.
%
% Revision 1.2  2001/02/12 22:09:51  mary
% Added sendmail action.
%
% Revision 1.1  2001/01/24 20:01:26  mary
% Renamed cgi_run.pro to kwcgirun.pro.
%
% Revision 1.4  2001/01/24 19:39:47  mary
% Use 'cgi_main' instead of 'main'. Simply compile cgi_run.pro for a .plm.
%
% Revision 1.3  2001/01/05 18:35:12  mary
% Close session properly upon completion. Increase buffer for cgiWrite.
% Redirect to original script if the session file has been deleted.
%
% Revision 1.2  2001/01/04 22:33:55  mary
% Fixed CGI interface to work with current basic reasoner's session saving.
%
% Revision 1.1.1.1  2000/12/04 21:03:11  mary
% Added CGI interface.
%

/*
cgiTest :-
   assert(fact(a,$1$)),
   assert(fact(a,$2$)),
   assert(fact(b,$3$)).
*/

% ------------------------- Error Handling -------------------------- %

%
% cgiErrorNote
%
% Outputs an explanatory note of what the user should do on an
% internal error
%
cgiErrorNote :-
   cgiSend($Internal Error -- Contact Amzi!$).
cgiErrorNote.

% --------------------- Loading the Logic-Base ---------------------- %

%
% cgiLoad
%
% This is where you load the logic-base or other definitions, 
% and set-up a log file, if needed.
%
cgiLoad :-
   %
   % Uncomment these to force a log file when consulting the logic-base
   % (cgiLoad) is not working.
   %
%   asserta(system('Log File', 'C:\\InetPub\\Scripts\\trace.html')),
%   asserta(system('Log File URL', '/trace.html')),

   % Try this first, seems to work best
%   debug_init($C:\\InetPub\\Scripts\\kwcgi.log$),
%   debug_init($/usr/local/apache/data/www.amzi.com/temp/kwcgi.log$),
   !.
cgiLoad :-
   throw($ERROR: cgiLoad failed\n$).


% ------------------------- Main Program ---------------------------- %

%
% cgiMain
%
% The start of the KnowledgeWright Engine.
%
cgiMain :-
   % Send a header first so errors, etc. appear
   cgiSend($Content-type: text/html$),
%   cgiSend($Cache-Control: no-cache$),
   cgiSend($$),

   % Fix new form facts with multiple values into single ones
   findall(A, fact(A, V), FACTS),
   once(cgi_fix_multi(FACTS)),

   % Load facts from a cookie (already saved as lists)
%   once(load_cookie),

   % Load parameters from the query string (after the ?)
   once(cgi_load_query_string(QUERYSTRING)),

   % Save it in case of error
   assert(system(query_string, QUERYSTRING)),

   % Start the log file after loading the facts so they are outputted
   version(AMZIVER), 
   cgiLog([$Amzi! Version: $, AMZIVER, $<BR>$]),

   % Start it up
   catch(
      (
         cgi_initlist(QUERYSTRING, INITLIST, KBNAME),
         kwi(0, initialize(INITLIST), _),
         kwi(0, open(KBNAME), _),

         % Create a session id
         cgi(remote_addr, ADDRESS),
         stringlist_concat([$session_$, ADDRESS], SESSION_ID),

         % If there are facts to assert this is not our first time
         % through, otherwise create a new session
         (fact(_, _) ->
            % Assert our form facts (newly entered and hidden)
            cgi_assert_facts(SESSION_ID)
         ;
            % Create a session if this is the first time through
            kwi(SESSION_ID, new_session, _)
         ),

         % Start solving
         kwi(SESSION_ID, solve, MORE),

         cgi_take_actions(SESSION_ID),

         % Close the session if we're done
         (MORE = more -> true
         ; kwi(SESSION_ID, close, _)
         )
      ),
      ERROR,
      cgi_processError(ERROR) ),

   true.
cgiMain :-
   throw($ERROR: Main CGI script failed\n$).

% All the parameters are in the query string pick them up
cgi_initlist(QUERYSTRING, INITLIST, KBNAME) :-
   % Determine Windows vs. Unix by the script name
   cgi(script_name, EXENAME),
   ((sub_string(EXENAME, _, _, $.exe$) ; sub_string(EXENAME, _, _, $.EXE$)) ->
      DELIMITER = $\\$
    ; DELIMITER = $/$ ),

   % All the parameters are in the query string, pick them up
   (system(directory, DIRECTORY) ->
      string_atom(SDIRECTORY, DIRECTORY),
      stringlist_concat([SDIRECTORY, DELIMITER], SSDIRECTORY),
      DIRLIST1 = [directory = SSDIRECTORY]
   ;  
      curdir(CURDIR),
      stringlist_concat([CURDIR, DELIMITER], SCURDIR),
      DIRLIST1 = [directory = SCURDIR] ),
   (system(temp_directory, TDIRECTORY) ->
      string_atom(STDIRECTORY, TDIRECTORY),
      stringlist_concat([STDIRECTORY, DELIMITER], SSTDIRECTORY),
      DIRLIST2 = [session_directory = SSTDIRECTORY]
   ;  
      curdir(TCURDIR),
      stringlist_concat([TCURDIR, DELIMITER], STCURDIR),
      DIRLIST2 = [session_directory = STCURDIR] ),
   (system(log_file, LOGFILE) ->
      string_atom(SLOGFILE, LOGFILE),
      LOGLIST = [log_file = SLOGFILE, message_level = high]
   ;  
      LOGLIST = [] ),
   (system(kb_file, KBFILE) ->
      string_atom(SKBFILE, KBFILE),
      KBNAME = SKBFILE
   ;  
      system('XPL File', XPLFILE),
      atomlist_concat([XPLFILE, '.kb'], AKBNAME),
      string_atom(KBNAME, AKBNAME) ),
   (QUERYSTRING = $$ ->
      PARAMLIST = [cgi_parameters = $$]
   ;
      stringlist_concat([$?$, QUERYSTRING], QUERYSTRING2),
      PARAMLIST = [cgi_parameters = QUERYSTRING2] ),

   append(DIRLIST1, DIRLIST2, DIRLIST),
   append(DIRLIST, LOGLIST, INITLIST0),
   % Can be local, logfile, or filename
   append([debug_msgs = local], INITLIST0, INITLIST1),
   append(INITLIST1, PARAMLIST, INITLIST).

% On unknown session errors, restart the whole script
cgi_processError(kwi_error(SID)) :-
   kwi(SID, get_error, ERROR),
   member(error = unknown_session, ERROR),
   cgiRewind,
   cgiSend($Status: 302$),
   cgi(server_name, SERVER),
   cgi(server_port, PORT),
   cgi(script_name, SCRIPT),
   system(query_string, QUERYSTRING),
   (QUERYSTRING = $$ ->
      cgiSend([$Location: http://$, SERVER, $:$, PORT, SCRIPT, $\n\n$])
   ;
      cgiSend([$Location: http://$, SERVER, $:$, PORT, SCRIPT, $?$, QUERYSTRING, $\n\n$])
   ).
% Otherwise if its a kwi error, get the details and throw
cgi_processError(kwi_error(SID)) :-
   kwi(SID, get_error, ERROR),
   throw(error('kwi_error', ERROR)).
% Unrecognized error throw it
cgi_processError(ERROR) :-
   throw(ERROR).
   
cgi_assert_facts(SID) :-
   fact(NAME, VALUE),
   not(string_icomp(NAME, $submit$)),
   once kwi(SID, replace(fact(NAME, VALUE)), _),
   fail.
cgi_assert_facts(_).

cgi_take_actions(SID) :-
   once kwi(SID, get_action, ACTION),
   ACTION \= none,
   once cgi_take_action(SID, ACTION),
   cgi_take_actions(SID).
cgi_take_actions(_).

cgi_take_action(SID, ask(user,_,_)).
cgi_take_action(SID, ask(html,F,PROPS)) :-
   get_property(PROPS, html, HTML),
   cgiSend([$<P>$, HTML, $</P>$]).
cgi_take_action(SID, ask(X,F,PROPS)) :-
   throw(error(unknown_ask, [action=X, fact=F, properties=PROPS])).
cgi_take_action(SID, tell(user, PROPS)) :-
   get_property(PROPS, text, TEXT),
   cgiSend([$<P>$, TEXT, $</P>$]).
% Take external actions
cgi_take_action(SID, tell(external, PROPS)) :-
   member(type = sendmail, PROPS),
   !,
   cgi_sendmail(SID, PROPS).

%
% Fixes multivalued facts into a single fact whose value is a list
%
cgi_fix_multi([]) :- !.
cgi_fix_multi([A | REST]) :-
   % Skip facts that don't need converting
   fact(A,V),
   string(V),

   % Gather up one or more values
   once findall(VALUE, retract(fact(A,VALUE)), VLIST),
   (VLIST = [ONE] ->
      assert(fact(A, V))
   ;
      assert(fact(A, VLIST)) 
   ),
   cgi_fix_multi(REST).
cgi_fix_multi([_ | REST]) :-
   cgi_fix_multi(REST).

%
% Loads system variables from the query string after the ? 
% in the executable name
%
cgi_load_query_string(DQStr) :-
   cgi(query_string, QStr),
   nonblank_string(QStr), 
   catch(
      (
      cgiDecodeURL(QStr, DQStr),
      string_termq(DQStr, QList)
      ),
      Err,
      throw([$ERROR: Invalid query string (after the ?), must be a list in square brackets: $, QStr, $<P>$, Err])
      ),
   cgi_assert_query_string(QList).
cgi_load_query_string($$) :-
   cgi(query_string, QStr), 
   nonblank_string(QStr),
   !,
   throw([$ERROR: Invalid syntax for the query string (after the ? in the executable name): $, QStr, $ -- Must be a list of name=value in square brackets []$]).
cgi_load_query_string($$).

cgi_assert_query_string([]) :- !.
cgi_assert_query_string([Name = Value | T]) :-
   asserta(system(Name, Value)),
   cgi_assert_query_string(T).

% Email Action
cgi_sendmail(SID, PropList) :-
   once kwi(SID, get_session, ILIST),
   once member(known = FactList, ILIST),
   (once(cgi_email_write_file(PropList, FactList, FileName)) ->
      true
   ;  throw([$ERROR: Unable to write email to a temporary file$]) ),
   (member(command = EMailCommand, PropList) ->
      true
   ;  throw([$ERROR: No command specified for sendmail action$]) ),
   stringlist_concat([EMailCommand, $ <$, FileName], MailCmdLine),
   (system(MailCmdLine) ->
      true
   ;  throw([$ERROR: Unable to execute command line for sendmail action$]) ),
   (delfile(FileName, _) ->
      true
   ;  throw([$ERROR: Unable to delete temporary email file$]) ),
   true.
cgi_sendmail(_, PropList) :-
   (member(goal = NAME, PropList) ->
      true
   ; NAME = $*unknown action*$ ),
   throw([$ERROR: Unable to execute sendmail action: $, NAME]).

cgi_email_write_file(Props, FactList, FileName) :-
   time(Hour, Min, Sec),
   string_integer(HourS, Hour),
   string_integer(MinS, Min),
   string_integer(SecS, Sec),
   system(temp_directory, TDIRECTORY),
   string_atom(STDIRECTORY, TDIRECTORY),
   stringlist_concat([STDIRECTORY, $TMP_$, HourS, MinS, SecS, $.TXT$], FileName),
   fopen(H, FileName, w),

   (member(to = ToAddr, Props) ->
      write(H, $To: $),
      write(H, ToAddr), nl(H)
   ;  throw([$ERROR: No 'to' address specified for sendmail action$]) ),

   (member(from = FromAddr, Props) ->
      write(H, $From: $), 
      write(H, FromAddr), nl(H)
   ;  throw([$ERROR: No 'from' address specified for sendmail action$]) ),

   (member(cc = CCAddr, Props) ->
      true
   ;  CCAddr = $$ ),
   write(H, $cc: $), 
   write(H, CCAddr), nl(H),

   (member(bcc = BCCAddr, Props) ->
      true
   ;  BCCAddr = $$ ),
   write(H, $bcc: $), 
   write(H, BCCAddr), nl(H),

   (member(subject = Subject, Props) ->
      true
   ;  Subject = $$ ),
   write(H, $subject: $), 
   write(H, Subject), nl(H),

   % Blank line after header
   nl(H),

   (member(message = Message, Props) ->
      true
   ;  Message = $$ ),
   write(H, Message), nl(H),

   write(H, $\n\nThe User Entered the Following Information:\n\n$),
   cgi_email_write_list(H, FactList),

   findall(A : B, cgi(A, B), CGIList),
   write(H, $\n\nThe System Gathered this Additional Information:\n\n$),
   cgi_email_write_list(H, CGIList),

   fclose(H),
   !.


cgi_email_write_list(H, []) :- !.
cgi_email_write_list(H, [F : V | Rest]) :-
   write(H, F),
   write(H, $ = $),
   write(H, V),
   nl(H),
   cgi_email_write_list(H, Rest).
cgi_email_write_list(H, [fact(F, V) | Rest]) :-
   write(H, F),
   write(H, $ = $),
   write(H, V),
   nl(H),
   cgi_email_write_list(H, Rest).

/*
user_bugwrite(T) :-
   cgiLog(T),
   string_termq(S, T),
   string_list(S, L),
   cgiExpandChars(L, L1),
   string_list(S1, L1),
   cgiLog(S1),
   cgiLog($<br>\n$).
*/
