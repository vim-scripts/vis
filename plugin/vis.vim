" vis.vim:
" Function:	Perform an Ex command on a visual highlighted block (CTRL-V).
" Version:	16
" Date:		Apr 14, 2005
" GetLatestVimScripts: 1066 1 cecutil.vim
" GetLatestVimScripts: 1195 1 :AutoInstall: vis.vim

" ---------------------------------------------------------------------
"  Details: {{{1
" Requires: Requires 6.0 or later  (this script is a plugin)
"           Requires <cecutil.vim> (see :he vis-required)
"
" Usage:    Mark visual block (CTRL-V) or visual character (v),
"           press ':B ' and enter an Ex command [cmd].
"
"           ex. Use ctrl-v to visually mark the block then use
"                 :B cmd     (will appear as   :'<,'>B cmd )
"
"           ex. Use v to visually mark the block then use
"                 :B cmd     (will appear as   :'<,'>B cmd )
"
"           Command-line completion is supported for Ex commands.
"
" Note:     There must be a space before the '!' when invoking external shell
"           commands, eg. ':B !sort'. Otherwise an error is reported.
"
" Author:   Charles E. Campbell <NdrchipO@ScampbellPfamily.AbizM> - NOSPAM
"           Based on idea of Stefan Roemer <roemer@informatik.tu-muenchen.de>
"
" ------------------------------------------------------------------------------
" Initialization: {{{1
" Exit quickly when <Vis.vim> has already been loaded or
" when 'compatible' is set
if &cp || exists("g:loaded_vis")
  finish
endif
let s:keepcpo    = &cpo
let g:loaded_vis = "v16"
set cpo&vim

" ------------------------------------------------------------------------------
" Public Interface: {{{1
"  -range       : VisBlockCmd operates on the range itself
"  -com=command : Ex command and arguments
"  -nargs=+     : arguments may be supplied, up to any quantity
com! -range -nargs=+ -com=command    B  silent <line1>,<line2>call s:VisBlockCmd(<q-args>)
com! -range -nargs=* -com=expression S  silent <line1>,<line2>call s:VisBlockSearch(<q-args>)

" Suggested by Hari --
vn // <esc>/<c-r>=<SID>VisBlockSearch()<cr>
vn ?? <esc>?<c-r>=<SID>VisBlockSearch()<cr>

" ---------------------------------------------------------------------
"  Support Functions: {{{1
" ------------------------------------------------------------------------------
" VisBlockCmd: {{{2
fun! <SID>VisBlockCmd(cmd) range
"  call Dfunc("VisBlockCmd(cmd<".a:cmd.">")

  " retain and re-use same visual mode
  norm `<
  let curposn = SaveWinPosn()
  let vmode   = visualmode()
"  call Decho("vmode<".vmode.">")

  " save options which otherwise may interfere
  let keep_lz    = &lz
  let keep_fen   = &fen
  let keep_ic    = &ic
  let keep_magic = &magic
  let keep_sol   = &sol
  let keep_ve    = &ve
  let keep_ww    = &ww
  set lz
  set magic
  set nofen
  set noic
  set nosol
  set ve=
  set ww=

  " Save any contents in register a
  let rega= @a

  if vmode == 'V'
"   call Decho("cmd<".a:cmd.">")
   exe "'<,'>".a:cmd
  else

   " Initialize so begcol<endcol for non-v modes
   let begcol   = s:VirtcolM1("<")
   let endcol   = s:VirtcolM1(">")
   if vmode != 'v'
    if begcol > endcol
     let begcol  = s:VirtcolM1(">")
     let endcol  = s:VirtcolM1("<")
    endif
   endif

   " Initialize so that begline<endline
   let begline  = a:firstline
   let endline  = a:lastline
   if begline > endline
    let begline = a:lastline
    let endline = a:firstline
   endif
"   call Decho('beg['.begline.','.begcol.'] end['.endline.','.endcol.']')

   " =======================
   " Modify Selected Region:
   " =======================
   " 1. delete selected region into register "a
"   call Decho("delete selected region into register a")
   norm! gv"ad

   " 2. put cut-out text at end-of-file
"   call Decho("put cut-out text at end-of-file")
   $
   pu_
   let lastline= line("$")
   silent norm! "ap
"   call Decho("reg-A<".@a.">")

   " 3. apply command to those lines
"   call Decho("apply command to those lines")
   exe '.,$'.a:cmd

   " 4. visual-block select the modified text in those lines
"   call Decho("visual-block select modified text at end-of-file")
   exe lastline
   exe "norm! 0".vmode."G$\"ad"

   " 5. delete excess lines
"   call Decho("delete excess lines")
   silent exe lastline.',$d'

   " 6. put modified text back into file
"   call Decho("put modifed text back into file (beginning=".begline.".".begcol.")")
   exe begline
   if begcol > 1
    exe 'norm! '.begcol."\<bar>\"ap"
   elseif begcol == 1
    norm! 0"ap
   else
    norm! 0"aP
   endif

   " 7. attempt to restore gv -- this is limited, it will
   " select the same size region in the same place as before,
   " not necessarily the changed region
   let begcol= begcol+1
   let endcol= endcol+1
   silent exe begline
   silent exe 'norm! '.begcol."\<bar>".vmode
   silent exe endline
   silent exe 'norm! '.endcol."\<bar>\<esc>"
   silent exe begline
   silent exe 'norm! '.begcol."\<bar>"
  endif

  " restore register a and options
"  call Decho("restore register a, options, and window pos'n")
  let @a  = rega
  let &lz = keep_lz
  let &fen= keep_fen
  let &ic = keep_ic
  let &sol= keep_sol
  let &ve = keep_ve
  let &ww = keep_ww
  call RestoreWinPosn(curposn)

"  call Dret("VisBlockCmd")
endfun

" ------------------------------------------------------------------------------
" VisBlockSearch: {{{2
fun! <SID>VisBlockSearch(...) range
"  call Dfunc("VisBlockSearch() a:0=".a:0." lines[".a:firstline.",".a:lastline."]")
  let keepic= &ic
  set noic

  if a:0 >= 1 && strlen(a:1) > 0
   let pattern   = a:1
   let s:pattern = pattern
"   call Decho("a:0=".a:0.": pattern<".pattern.">")
  elseif exists("s:pattern")
   let pattern= s:pattern
  else
   let pattern   = @/
   let s:pattern = pattern
  endif
  let vmode= visualmode()

  " collect search restrictions
  let firstline  = line("'<")
  let lastline   = line("'>")
  let firstcolm1 = s:VirtcolM1("<")
  let lastcolm1  = s:VirtcolM1(">")
"  call Decho("1: firstline=".firstline." lastline=".lastline." firstcolm1=".firstcolm1." lastcolm1=".lastcolm1)

  if(firstline > lastline)
   let firstline = line("'>")
   let lastline  = line("'<")
   if a:0 >= 1
    norm! `>
   endif
  else
   if a:0 >= 1
    norm! `<
   endif
  endif
"  call Decho("2: firstline=".firstline." lastline=".lastline." firstcolm1=".firstcolm1." lastcolm1=".lastcolm1)

  if vmode != 'v'
   if firstcolm1 > lastcolm1
   	let tmp        = firstcolm1
   	let firstcolm1 = lastcolm1
   	let lastcolm1  = tmp
   endif
  endif
"  call Decho("3: firstline=".firstline." lastline=".lastline." firstcolm1=".firstcolm1." lastcolm1=".lastcolm1)

  let firstlinem1 = firstline  - 1
  let lastlinep1  = lastline   + 1
  let firstcol    = firstcolm1 + 1
  let lastcol     = lastcolm1  + 1
  let lastcolp1   = lastcol    + 1
"  call Decho("4: firstline=".firstline." lastline=".lastline." firstcolm1=".firstcolm1." lastcolp1=".lastcolp1)

  " construct search string
  if vmode == 'V'
   let srch= '\%(\%>'.firstlinem1.'l\%<'.lastlinep1.'l\)\&'
"   call Decho("V  srch: ".srch)
  elseif vmode == 'v'
   if firstline == lastline || firstline == lastlinep1
   	let srch= '\%(\%'.firstline.'l\%>'.firstcolm1.'v\%<'.lastcolp1.'v\)\&'
   else
    let srch= '\%(\%(\%'.firstline.'l\%>'.firstcolm1.'v\)\|\%(\%'.lastline.'l\%<'.lastcolp1.'v\)\|\%(\%>'.firstline.'l\%<'.lastline.'l\)\)\&'
   endif
"   call Decho("v  srch: ".srch)
  else
   let srch= '\%(\%>'.firstlinem1.'l\%>'.firstcolm1.'v\%<'.lastlinep1.'l\%<'.lastcolp1.'v\)\&'
"   call Decho("^v srch: ".srch)
  endif

  " perform search
  if a:0 <= 1
"   call Decho("Search forward: <".srch.pattern.">")
   call search(srch.pattern)
   let @/= srch.pattern

  elseif a:0 == 2
"   call Decho("Search backward: <".srch.pattern.">")
   call search(srch.pattern,a:2)
   let @/= srch.pattern
  endif

  " restore ignorecase
  let &ic= keepic

"  call Dret("VisBlockSearch <".srch.">")
  return srch
endfun

" ------------------------------------------------------------------------------
" VirtcolM1: usually a virtcol(mark)-1, but due to tabs this can be different {{{2
fun! s:VirtcolM1(mark)
"  call Dfunc("VirtcolM1(mark ".a:mark.")")
  let mark="'".a:mark

  if virtcol(mark) <= 1
"   call Dret("VirtcolM1 0")
   return 0
  endif
"  call Decho("exe norm! `".a:mark."h")
  exe "norm! `".a:mark."h"

"  call Dret("VirtcolM1 ".virtcol("."))
  return virtcol(".")
endfun

let &cpo= s:keepcpo
unlet s:keepcpo
" ------------------------------------------------------------------------------
"  Modelines: {{{1
" vim: fdm=marker
" HelpExtractor:
"  Author:	Charles E. Campbell, Jr.
"  Version:	3
"  Date:	Sep 09, 2004
"
"  History:
"    v2 Nov 24, 2003 : On Linux/Unix, will make a document directory
"                      if it doesn't exist yet
"
" GetLatestVimScripts: 748 1 HelpExtractor.vim
" ---------------------------------------------------------------------
set lz
let s:keepcpo= &cpo
set cpo&vim
let docdir = substitute(expand("<sfile>:r").".txt",'\<plugin[/\\].*$','doc','')
if !isdirectory(docdir)
 if has("win32")
  echoerr 'Please make '.docdir.' directory first'
  unlet docdir
  finish
 elseif !has("mac")
  exe "!mkdir ".docdir
 endif
endif

let curfile = expand("<sfile>:t:r")
let docfile = substitute(expand("<sfile>:r").".txt",'\<plugin\>','doc','')
exe "silent! 1new ".docfile
silent! %d
exe "silent! 0r ".expand("<sfile>:p")
silent! 1,/^" HelpExtractorDoc:$/d
exe 'silent! %s/%FILE%/'.curfile.'/ge'
exe 'silent! %s/%DATE%/'.strftime("%b %d, %Y").'/ge'
norm! Gdd
silent! wq!
exe "helptags ".substitute(docfile,'^\(.*doc.\).*$','\1','e')

exe "silent! 1new ".expand("<sfile>:p")
1
silent! /^" HelpExtractor:$/,$g/.*/d
silent! wq!

set nolz
unlet docdir
unlet curfile
"unlet docfile
let &cpo= s:keepcpo
unlet s:keepcpo
finish

" ---------------------------------------------------------------------
" Put the help after the HelpExtractorDoc label...
" HelpExtractorDoc:
*vis.txt*	The Visual Block Tool				Mar 01, 2005

Author:  Charles E. Campbell, Jr.  <NdrchipO@ScampbellPfamily.AbizM>
	  (remove NOSPAM from Campbell's email first)

==============================================================================
1. Contents						*vis* *vis-contents*

	1. Contents......................: |vis-contents|
	2. Visual Block Manual...........: |vis-manual|
	3. Visual Block Search...........: |vis-srch|
	4. Required......................: |vis-required|
	5. History.......................: |vis-history|

==============================================================================

2. Visual Block Manual			*visman* *vismanual* *vis-manual* *v_:B*

	Performs an arbitrary Ex command on a visual highlighted block.

	Mark visual block (CTRL-V) or visual character (v),
		press ':B ' and enter an Ex command [cmd].

		ex. Use ctrl-v to visually mark the block then use
			:B cmd     (will appear as   :'<,'>B cmd )

		ex. Use v to visually mark the block then use
			:B cmd     (will appear as   :'<,'>B cmd )

	Command-line completion is supported for Ex commands.

	There must be a space before the '!' when invoking external shell
	commands, eg. ':B !sort'. Otherwise an error is reported.

	Doesn't work as one might expect with Vim's ve option.  That's
	because ve=all ended up leaving unwanted blank columns, so the
	solution chosen was to have the vis function turn ve off temporarily.

	The script works by deleting the selected region into register "a.
	The register "a itself is first saved and later restored.  The text is
	then put at the end-of-file, modified by the user command, and then
	deleted back into register "a.  Any excess lines are removed, and the
	modified text is then put back into the text at its original
	location.

	Based on idea of Stefan Roemer <roemer@informatik.tu-muenchen.de>;
	the implementation and method has completely changed since the
	original.

==============================================================================

3. Visual Block Search				*vis-search* *vis-srch* *vis-S*

	Visual block search provides two ways to get visual-selection
	based searches.  Both these methods work well with :set hls
	and searching may be repeated with the n or N commands.
	
	Using / and ? after a visual selection:
>
		ex. select region via V, v, or ctrl-v
		    /pattern
<
	    You'll actually get a long leader string of commands to restrict
	    searches to the requested visual block first.  You may then enter
	    the pattern afterwards.  For example, using "v" to select this
	    paragraph, you'll see something like: >

		/\%(\%(\%63l\%>12c\)\|\%(\%66l\%<51c\)\|\%(\%>63l\%<66l\)\)\&
<
	    You may enter whatever pattern you want after the \&, and the
	    pattern search will be restricted to the requested region.
	
	The "S" command in visual mode:
>
		ex. select region via V, v, or ctrl-v
		    :S pattern
<
	    The ":S pattern" will appear as ":'<,'>S pattern".  This
	    command will move the cursor to the next instance of the
	    pattern, restricted to the visually selected block.
	
	An "R" command was contemplated, but I currently see no way to
	get it to continue to search backwards with n and N commands.


==============================================================================

4. Required							*vis-required*

	Since the <vis.vim> function is a plugin, it uses several 6.0 (or
	later) features.  Please use a 6.0 or later version of vim.

	Starting with version 11, <vis.vim> required <cecutil.vim>.  It uses
	the SaveWinPosn() and RestoreWinPosn() functions therein.  You may get
	<cecutil.vim> from

   		http://mysite.verizon.net/astronaut/vim/index.html#VimFuncs
   		as "DrC's Utilities".

==============================================================================

5. History							*vis-history*

    v16 : Feb 02, 2005  - fixed a bug with visual-block + S ; the first line
			  was being omitted in the search
	  Mar 01, 2005  - <q-args> used instead of '<args>'
	  Apr 13, 2005  - :'<,'>S plus v had a bug with one or two line
	                  selections (tnx to Vigil for pointing this out)
	  Apr 14, 2005  - set ignorecase caused visual-block searching
	                  to confuse visual modes "v" and "V"
    v15 : Feb 01, 2005  - includes some additions to the help
    v14 : Sep 28, 2004	- visual-block based searching now supported.  One
			  do this either with :'<,'>S pattern or with a / or ?
	  Jan 31, 2005  - fixed help file
    v13 : Jul 16, 2004	- folding commands added to source
			- GetLatestVimScript hook added for automatic updating
    v12 : Jun 14, 2004	- bugfix (folding interfered)
    v11 : May 18, 2004	- Included calls to SaveWinPosn() and RestoreWinPosn()
			  to prevent unwanted movement of the cursor and window.
			  As a result, <vis.vim> now requires <cecutil.vim>
			  (see |vis-required|).
    v10 : Feb 11, 2003	- bugfix (ignorecase option interfered with v)
     v9 : Sep 10, 2002	- bugfix (left Decho on, now commented out)
     v8 : Sep 09, 2002	- bugfix (first column problem)
     v7 : Sep 05, 2002	- bugfix (was forcing begcol<endcol for "v" mode)
     v6 : Jun 25, 2002	- bugfix (VirtcolM1 instead of virtcol()-1)
     v5 : Jun 21, 2002	- now supports character-visual mode (v) and
			  linewise-visual mode (V)
     v4 : Jun 20, 2002	- saves sol, sets nosol, restores sol
			- bugfix: 0 inserted: 0\<c-v>G$\"ad
			- Fixed double-loading (was commented
			  out for debugging purposes)
     v3 : Jun 20, 2002	- saves ve, unsets ve, restores ve
     v2 : Jun 19, 2002	- Charles Campbell's <vis.vim>
     v?   June 19, 2002	  Complete rewrite - <vis.vim> is now immune to
			  the presence of tabs and is considerably faster.
     v1 Epoch		- Stefan Roemer <roemer@informatik.tu-muenchen.de>
			  wrote the original <vis.vim>.

vim:tw=78:ts=8:ft=help
