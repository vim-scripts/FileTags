" Key is filename, value is a list of tags.
let g:FileTags_data = MultiDictionary#New()

" Tag file format:
"
" Filename<tab>Tag1 Tag2...<tag>Original file (case sensitive)
"
" SALMAN: Change to read local file, if one is there.
function! FileTags#ReadTagFile()
  let g:FileTags_data.data = {}

  for dictionaryName in [ 'local', 'global' ]
    let tagFile = dictionaryName == 'global' ? g:FileTags_file : g:FileTags_localFile

    if ( !filereadable( tagFile ) )
      continue
    endif

    let contents = readfile( tagFile )

    for line in contents
      let splitLine = split( line, "\t" )

      call FileTags#SetTags( splitLine[ 0 ], functions#AddWithSpace( splitLine[ 1 ], dictionaryName ), splitLine[ 2 ] )
    endfor
  endfor
endfunction

" SALMAN: Old method; has no real bearing any more, especially with the updated g:FileTags_data multi-dictionary format.
" function! FileTags#UpdateTagFileFormat()
"   let data            = g:FileTags_data
"   let g:FileTags_data = {}
"
"   for key in keys( data )
"     call FileTags#SetTags( tolower( key ), data[ key ], key )
"   endfor
" endfunction

function! FileTags#WriteTagFile( name, deleting, originalName )
  " Save the tags for the current name and read, overwriting the contents of our data with what's in the actual file. Then, put in the data for just the one file
  " we're just manipulating. Finally, write it out.
  let savedTags = FileTags#GetTags( a:name, 0 )

  call FileTags#ReadTagFile()

  if ( a:deleting )
    if ( g:FileTags_data.has_key( a:name ) )
      call g:FileTags_data.remove( a:name )
    endif
  else
    call FileTags#SetTags( a:name, savedTags, a:originalName )
  endif

  for dictionaryName in [ 'local', 'global' ]
    if ( g:FileTags_data.has_dictionary( dictionaryName ) )
      let dictionary = g:FileTags_data.get_dictionary( dictionaryName )

      let contents = []

      for filename in keys( dictionary )
        let contents += [ filename . "\t" . FileTags#GetTags( filename, 0 ) . "\t" . FileTags#GetOriginalName( filename ) ]
      endfor

      let tagFile = dictionaryName == 'global' ? g:FileTags_file : g:FileTags_localFile

      call writefile( sort( contents ), tagFile )
    endif
  endfor
"   let contents = []
"
"   for filename in g:FileTags_data.keys()
"     let contents += [ filename . "\t" . FileTags#GetTags( filename, 0 ) . "\t" . FileTags#GetOriginalName( filename ) ]
"   endfor
"
"   call writefile( sort( contents ), g:FileTags_file )
endfunction

function! FileTags#GetOriginalName( name )
  if ( g:FileTags_data.has_key( a:name ) )
    return g:FileTags_data.get( a:name ).originalName
  endif

  return fnamemodify( a:name, ':p' )
endfunction

function! FileTags#NormalizeFileName( name )
  let result = a:name

  if ( !g:FileTags_caseSensitiveFileNames )
    let result = tolower( result )
  endif

  if ( !g:FileTags_slashSensitiveFileNames )
    let result = substitute( result, '\\', '/', 'g' )
  endif

  return result
endfunction

function! FileTags#ResolveFileName( nameList, normalize )
  let result = expand( "%:p" )

  if ( len( a:nameList ) > 0 && a:nameList[ 0 ] != '' )
    let result = a:nameList[ 0 ]
  endif

  return a:normalize ? FileTags#NormalizeFileName( result ) : result
endfunction

function! FileTags#GetAutomaticTags( name )
  let result    = ''
  let extraTags = ''
  let type      = ''

  let name = a:name

  if ( isdirectory( name ) )
    let extraTags = 'directory'
    let type      = 'directory'
  elseif ( filereadable( name ) )
    " Put in the file name words (split on underscore, space or capital) by default.
    let extraTags = substitute( name, '_', ' ', 'g' )
    let extraTags = functions#MakeWords( fnamemodify( extraTags, ":t:r" ) )

    let extraTags = functions#AddWithSpace( extraTags, 'file' )
    let type      = 'file'
  elseif ( name =~? '^http:' )
    let extraTags = 'url'
    let type      = 'file'
  endif

  if ( type == 'file' || type == 'directory' )
    let name = fnamemodify( name, ':p' )
  endif

  let pathComponents = join( split( name, '[/\\]' ), ' ' )

  let result = functions#AddWithSpace( result, pathComponents )
  let result = functions#AddWithSpace( result, extraTags )

  return FileTags#NormalizeTags( result )
endfunction

function! FileTags#HasTag( tag, ... )
  let tags = FileTags#GetTags( FileTags#ResolveFileName( a:000, 1 ), 1 )

  return FileTags#ContainsTag( a:tag, tags )
endfunction

function! FileTags#ContainsTag( tag, tags )
  return a:tags =~ '\<' . FileTags#NormalizeTags( a:tag ) . '\>'
endfunction

function! FileTags#GetTags( name, includeExtension )
  let result = ''

  if ( g:FileTags_data.has_key( a:name ) )
    let result = g:FileTags_data.get( a:name ).tags
  endif

  if ( a:includeExtension )
    let extension = fnamemodify( a:name, ":e" )

    if ( extension != '' && result !~? '\<' . extension . '\>' )
      let result = functions#AddWithSpace( result, extension )
    endif
  endif

  return FileTags#NormalizeTags( result )
endfunction

" Given a list of whitespace separated tags, removes duplicates and sorts the result. Calling with "b a c a c b" returns "a b c". Also, removes all
" non-alphanumeric and non-underscore characters.
function! FileTags#NormalizeTags( tags )
  return join( functions#SortUnique( split( substitute( substitute( tolower( a:tags ), '\.', ' ', 'g' ), '\c[^a-z0-9_[:space:]]\+', '', 'g' ), '\s\+' ) ), ' ' )
endfunction

" Cannot be used to remove all tags. Empty return value is the same as cancelling input and the tags don't get changed.
function! FileTags#EditTags( bang, ... )
  let resolvedName = FileTags#ResolveFileName( a:000, 0 )
  let name         = FileTags#NormalizeFileName( resolvedName )
  let tags         = FileTags#GetTags( name, 0 )

  " If we have no tags, use the file name/path to figure out some default ones. Don't really need the functions#AddWithSpace bit, but will be useful if we decide
  " to take the if clause out at some point.
  if ( tags == '' || a:bang == '!' )
    let tags = FileTags#NormalizeTags( functions#AddWithSpace( tags, FileTags#GetAutomaticTags( resolvedName ) ) )
  endif

  let tags = input( 'Enter tags for ' . resolvedName . ': ', tags )

  if ( tags == '' )
    echo "Cancelling edit tags."

    return
  endif

  let tags = FileTags#NormalizeTags( tags )

  call FileTags#SetTags( name, tags, resolvedName )

  call FileTags#WriteTagFile( name, 0, resolvedName )
endfunction

function! FileTags#SetTags( name, tags, originalName )
  " Unless a tag specifically states that it's local, assume it's global.
  let dictionary = FileTags#ContainsTag( 'local', a:tags ) ? 'local' : 'global'

  call g:FileTags_data.put( dictionary, a:name, { 'tags': FileTags#NormalizeTags( a:tags ), 'originalName': a:originalName } )
endfunction

function! FileTags#RemoveAllTags( ... )
  let name = FileTags#ResolveFileName( a:000, 1 )

  if ( g:FileTags_data.has_key( name ) )
    echo printf( "Removing tags for %s: %s", name, FileTags#GetTags( name, 0 ) )

    call g:FileTags_data.remove( name )

    call FileTags#WriteTagFile( name, 1, '' )
  endif
endfunction

function! FileTags#GetTagMatches( ... )
  call FileTags#ReadTagFile()

  let tags = len( a:000 ) == 1 ? a:1 : a:000

  let currentList = g:FileTags_data.keys()

  for tag in tags
    let newList = []
    let tagExpression = '\<' . tag

    for filename in currentList
      let fileTags = FileTags#GetTags( filename, 1 )

      if ( fileTags =~? tagExpression )
        let newList += [ filename ]
      endif
    endfor

    let currentList = newList
  endfor

  return currentList
endfunction

function! FileTags#ListTagMatches( displayOnly, commandToExecute, ... )
  let currentList = sort( FileTags#GetTagMatches( a:000 ) )
  let numItems    = len( currentList )
  let maxLen      = functions#GetMaxLen( currentList )

  if ( numItems == 0 )
    echo "No tags match for " . join( a:000, ' ' )

    return
  endif

  if ( len( a:000 ) > 0 )
    echo printf( "Found %d %s for %s.", numItems, functions#SingularOrPlural( numItems, "match", "matches" ), join( a:000, ' ' ) )
  else
    echo printf( "Found %d %s.", numItems, functions#SingularOrPlural( numItems, "match", "matches" ) )
  endif

  let printableList = map( copy( currentList ), 'printf( "%-" . maxLen . "s <%s>", FileTags#GetOriginalName( v:val ), FileTags#GetTags( v:val, 0 ) )' )

  if ( a:displayOnly )
    echo join( printableList, "\<NL>" )

    return -1
  else
    let choice = 0

    if ( numItems > 1 )
      let prompt = a:commandToExecute == '' ? 'Select one to copy to the clipboard: ' : 'Select one to pass as an argument to ' . a:commandToExecute . ': '
      let choice = functions#InputFromList( printableList, prompt )

      echo "\n"
    endif

    redraw

    if ( choice < 0 )
      echo "Cancelling."

      return
    endif

    let chosenName = FileTags#GetOriginalName( currentList[ choice ] )

    if ( a:commandToExecute == '' )
      let @* = chosenName

      echo printf( "Copied %s (tag list: %s)", chosenName, FileTags#GetTags( currentList[ choice ], 0 ) )
    else
      execute a:commandToExecute . ' ' . chosenName
    endif
  endif

  return chosenName
endfunction

function! FileTags#ListTags( ... )
  call FileTags#ReadTagFile()

  let counts = {}
  let prefix = exists( "a:1" ) ? '^' . a:1 : ''

  for name in g:FileTags_data.keys()
    let tagList = split( FileTags#GetTags( name, 1 ), '\s\+' )

    for tag in tagList
      if ( prefix != '' && tag !~? prefix )
        continue
      endif

      if ( has_key( counts, tag ) )
        let counts[ tag ] += 1
      else
        let counts[ tag ] = 1
      endif
    endfor
  endfor

  for tag in sort( keys( counts ) )
    echo printf( "%-20s %d", tag, counts[ tag ] )
  endfor
endfunction

function! FileTags#ShowTags()
  call FileTags#ReadTagFile()

  let resolvedName = FileTags#ResolveFileName( a:000, 0 )
  let name         = FileTags#NormalizeFileName( resolvedName )
  let tags         = FileTags#GetTags( name, 0 )

  if ( tags == '' )
    echo printf( "No tags found for %s; automatic tags: %s", resolvedName, FileTags#GetAutomaticTags( name ) )
  else
    echo printf( "Tags for %s: %s", resolvedName, tags )
  endif
endfunction
