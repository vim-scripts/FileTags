if ( !exists( "g:FileTags_debug" ) && exists( "g:FileTags_loaded" ) || &compatible || version < 700 )
  finish
endif

let g:FileTags_loaded = 1

if ( !exists( "g:FileTags_file" ) )
  let g:FileTags_file = $VIM . '/FileTags'
endif

if ( !exists( "g:FileTags_localFile" ) )
  let g:FileTags_localFile = "c:/LocalFileTags"
endif

if ( !exists( "g:FileTags_caseSensitiveFileNames" ) )
  let g:FileTags_caseSensitiveFileNames = 0
endif

if ( !exists( "g:FileTags_slashSensitiveFileNames" ) )
  let g:FileTags_slashSensitiveFileNames = 0
endif

" Optional take a string and substring match--not case sensitive--the tag names.
" com! -nargs=? ListFileTags
"
" " Optionally takes two arguments and does a search/replace in the returned value.
" "
" " SALMAN: Need custom completion.
" com! -nargs=* CopyName

" Add, remove and edit file tags.
com! -nargs=? -bang -complete=file EditTags call FileTags#EditTags( <q-bang>, <f-args> )
com! -nargs=? -complete=file RemoveAllTags call FileTags#RemoveAllTags( <f-args> )
com! -nargs=* ListTagMatches call FileTags#ListTagMatches( 1, '', <f-args> )
com! -nargs=* CopyTagMatches call FileTags#ListTagMatches( 0, '', <f-args> )
com! -nargs=* CommandTagMatches call FileTags#ListTagMatches( 0, <f-args> )
com! -nargs=? ListTags call FileTags#ListTags( <f-args> )
com! -nargs=? ShowTags call FileTags#ShowTags()
