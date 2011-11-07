"=============================================================================
" Simple Unit Testing Framework for Vim script
"
" File    : autoload/unittest.vim
" Author	: h1mesuke <himesuke@gmail.com>
" Updated : 2011-11-08
" Version : 0.3.2
" License : MIT license {{{
"
"   Permission is hereby granted, free of charge, to any person obtaining
"   a copy of this software and associated documentation files (the
"   "Software"), to deal in the Software without restriction, including
"   without limitation the rights to use, copy, modify, merge, publish,
"   distribute, sublicense, and/or sell copies of the Software, and to
"   permit persons to whom the Software is furnished to do so, subject to
"   the following conditions:
"   
"   The above copyright notice and this permission notice shall be included
"   in all copies or substantial portions of the Software.
"   
"   THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS
"   OR IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF
"   MERCHANTABILITY, FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT.
"   IN NO EVENT SHALL THE AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY
"   CLAIM, DAMAGES OR OTHER LIABILITY, WHETHER IN AN ACTION OF CONTRACT,
"   TORT OR OTHERWISE, ARISING FROM, OUT OF OR IN CONNECTION WITH THE
"   SOFTWARE OR THE USE OR OTHER DEALINGS IN THE SOFTWARE.
" }}}
"=============================================================================

function! unittest#run(...)
  let args = a:000
  if empty(filter(copy(args), "v:val !~ '^[gv]/'"))
    " If no argument was given, process the current buffer.
    let args += ['%']
  endif

  let tc_files = []
  let test_filters = { 'g_pattern': "", 'v_pattern': "" }
  for value in args
    " Filtering pattern
    let matched = matchlist(value, '^\([gv]\)/\(.*\)$')
    if len(matched) > 0
      if matched[1] ==# 'g'
        let test_filters.g_pattern = matched[2]
      else
        let test_filters.v_pattern = matched[2]
      endif
      continue
    endif
    " Testcase file
    let path = expand(value)
    if path =~# '\<\(test_\|t[cs]_\)\w\+\.vim$'
      call add(tc_files, path)
      continue
    endif
    " Invalid value
    call unittest#print_error("unittest: Sourced file is not a testcase.")
    return
  endfor

  try
    let s:test_runner = s:TestRunner.new(test_filters)
    for tc_file in tc_files
      source `=tc_file`
    endfor
    call s:test_runner.run()
  catch
    call unittest#print_error(v:throwpoint)
    call unittest#print_error(v:exception)
  finally
    unlet! s:test_runner
  endtry
endfunction

function! unittest#runner()
  if !unittest#is_running()
    throw "unittest: :UnitTest is not running now."
  endif
  return s:test_runner
endfunction

function! unittest#is_running()
  return exists('s:test_runner')
endfunction

function! unittest#print_error(msg)
  echohl ErrorMsg | echomsg a:msg | echohl None
endfunction

function! s:get_SID()
  return matchstr(expand('<sfile>'), '<SNR>\d\+_')
endfunction
let s:SID = s:get_SID()
delfunction s:get_SID

"-----------------------------------------------------------------------------
" TestRunner

let s:TestRunner = unittest#oop#class#new('TestRunner', s:SID)

function! s:TestRunner_initialize(test_filters) dict
  let self.testcases = []
  let self.test_filters = a:test_filters
  let self.context = {}
  let self.results = s:TestResults.new()
  let self.out = s:OutBuffer.new()
endfunction
call s:TestRunner.method('initialize')

function! s:TestRunner_add_testcase(tc) dict
  call add(self.testcases, a:tc)
endfunction
call s:TestRunner.method('add_testcase')

function! s:TestRunner_run() dict
  if has("reltime")
    let start_time = reltime()
  endif
  call self.out.open()
  for tc in self.testcases
    let self.current_testcase = tc
    call self.out.print_header(1, tc.name)
    call tc.__initialize__()
    let tests = self.filter_tests(tc.tests())
    for test in tests
      let self.current_test = test
      call self.out.print_header(2, test)
      try
        call tc.__setup__(test)
        call call(tc[test], [], tc)
        call tc.__teardown__(test)
      catch
        call self.results.add_error()
      endtry
      call self.print_results_of(tc, test)
    endfor
    call tc.__finalize__()
  endfor
  call self.print_results()
  if has("reltime")
    let used_time = split(reltimestr(reltime(start_time)))[0]
    call self.out.puts("Finished in " . used_time . " seconds.")
  endif
  call self.out.close()
endfunction
call s:TestRunner.method('run')

function! s:TestRunner_filter_tests(tests) dict
  let tests = copy(a:tests)
  if self.test_filters.g_pattern != ""
    call filter(tests, 'v:val =~# self.test_filters.g_pattern')
  endif
  if self.test_filters.v_pattern != ""
    call filter(tests, 'v:val !~# self.test_filters.v_pattern')
  endif
  return tests
endfunction
call s:TestRunner.method('filter_tests')

function! s:TestRunner_count_assertion() dict
  call self.results.count_assertion()
endfunction
call s:TestRunner.method('count_assertion')

function! s:TestRunner_report_success() dict
  call self.results.add_success()
endfunction
call s:TestRunner.method('report_success')

function! s:TestRunner_report_failure(reason, hint) dict
  call self.results.add_failure(a:reason, a:hint)
endfunction
call s:TestRunner.method('report_failure')

function! s:TestRunner_print_results_of(tc, test) dict
  let line = ''
  for result in self.results.of(a:tc, a:test)
    if result.is_a(s:Failure)
      let line .= 'F'
    elseif result.is_a(s:Error)
      let line .= 'E'
    else
      let line .= '.'
    endif
  endfor
  if !empty(line)
    call self.out.puts('=> ' . line)
  endif

  for result in self.results.of(a:tc, a:test)
    if result.is_a(s:Failure)
      call self.out.print_failure(result)
    elseif result.is_a(s:Error)
      call self.out.print_error(result)
    endif
  endfor
endfunction
call s:TestRunner.method('print_results_of')

function! s:TestRunner_print_results() dict
  call self.out.puts()
  call self.out.print_separator('-')
  let number_of = self.results.number_of
  call self.out.puts(number_of.tests . " tests, " . number_of.assertions . " assertions, " .
        \ number_of.failures . " failures, " . number_of.errors . " errors")
  call self.out.puts()
endfunction
call s:TestRunner.method('print_results')

"-----------------------------------------------------------------------------
" Output

let s:Output = unittest#oop#class#new('Output', s:SID)

function! s:Output_get_width() dict
  return 78
endfunction
call s:Output.method('get_width')

function! s:Output_puts() dict
  throw "unittest: Abstract method was called unexpectedly!"
endfunction
call s:Output.method('puts')

function! s:Output_print_separator(ch) dict
  call self.puts(repeat(a:ch, self.get_width()))
endfunction
call s:Output.method('print_separator')

function! s:Output_print_header(level, title) dict
  call self.puts()
  if a:level == 1
    call self.print_separator('=')
    call self.puts(toupper(a:title))
  else
    call self.print_separator('-')
    call self.puts(a:title)
  endif
endfunction
call s:Output.method('print_header')

function! s:Output_print_failure(fail) dict
  call self.puts()
  let nr = printf('%3d) ', a:fail.nr)
  let head = nr . "Failure: " . a:fail.test . ": " . a:fail.assert
  if a:fail.hint != ""
    let head .= ": " . a:fail.hint
  endif
  call self.puts(head)
  call self.puts(split(a:fail.reason, "\n"))
endfunction
call s:Output.method('print_failure')

function! s:Output_print_error(err) dict
  call self.puts()
  let nr = printf('%3d) ', a:err.nr)
  call self.puts(nr . "Error: " . a:err.throwpoint)
  call self.puts(a:err.exception)
endfunction
call s:Output.method('print_error')

"---------------------------------------
" OutBuffer < Output

let s:OutBuffer = unittest#oop#class#new('OutBuffer', s:SID, s:Output)
let s:OutBuffer.nr = -1

function! s:OutBuffer_get_width() dict
  let winw = winwidth(bufwinnr(s:OutBuffer.nr))
  return (min([80, winw]) - 2)
endfunction
call s:OutBuffer.method('get_width')

function! s:OutBuffer_open() dict
  call self.open_window()
endfunction
call s:OutBuffer.method('open')

function! s:OutBuffer_open_window() dict
  if !bufexists(s:OutBuffer.nr)
    " The results buffer doesn't exist.
    split
    edit `='[unittest results]'`
    let s:OutBuffer.nr = bufnr('%')
  elseif bufwinnr(s:OutBuffer.nr) != -1
    " The results buffer exists, and it has a window.
    call self.focus_window()
  else
    " The results buffer exists, but it has no window.
    split
    execute 'buffer' s:OutBuffer.nr
  endif
  call self.init_buffer()
endfunction
call s:OutBuffer.method('open_window')

function! s:OutBuffer_focus_window() dict
  execute bufwinnr(s:OutBuffer.nr) 'wincmd w'
endfunction
call s:OutBuffer.method('focus_window')

function! s:OutBuffer_init_buffer() dict
  nnoremap <buffer> q <C-w>c
  setlocal bufhidden=hide buftype=nofile noswapfile nobuflisted
  setlocal filetype=unittest
  silent! %delete _
endfunction
call s:OutBuffer.method('init_buffer')

function! s:OutBuffer_close() dict
  call self.focus_window()
  normal! gg"_2ddGz-
endfunction
call s:OutBuffer.method('close')

function! s:OutBuffer_puts(...) dict
  let save_winnr =  bufwinnr('%')
  execute bufwinnr(s:OutBuffer.nr) 'wincmd w'
  let str  = (a:0 ? a:1 : "")
  call append('$', str)
  setlocal nomodified
  execute save_winnr 'wincmd w'
  if g:unittest_smooth_redraw_results
    normal! G
    redraw
  endif
endfunction
call s:OutBuffer.method('puts')

"---------------------------------------
" OutFile < Output

" TODO: 

"-----------------------------------------------------------------------------
" TestResults

let s:TestResults = unittest#oop#class#new('TestResults', s:SID)

function! s:TestResults_initialize() dict
  let self.results = {}
  let self.number_of = {
        \ 'tests'     : 0,
        \ 'assertions': 0,
        \ 'failures'  : 0,
        \ 'errors'    : 0,
        \ }
endfunction
call s:TestResults.method('initialize')

function! s:TestResults_of(tc, test) dict
  try
    let results = self.results[a:tc.name][a:test]
    return results
  catch /^Vim\%((\a\+)\)\=:E716:/
    " E716: Key not present in Dictionary:
    return []
  endtry
endfunction
call s:TestResults.method('of')

function! s:TestResults_count_assertion() dict
  let self.number_of.assertions += 1
endfunction
call s:TestResults.method('count_assertion')

function! s:TestResults_add_success() dict
  call self.append(s:succ)
endfunction
call s:TestResults.method('add_success')

function! s:TestResults_add_failure(reason, hint) dict
  let self.number_of.failures += 1
  let fail = s:Failure.new(a:reason, a:hint)
  let fail.nr = self.number_of.failures
  call self.append(fail)
endfunction
call s:TestResults.method('add_failure')

function! s:TestResults_add_error() dict
  let self.number_of.errors += 1
  let err = s:Error.new()
  let err.nr = self.number_of.errors
  call self.append(err)
endfunction
call s:TestResults.method('add_error')

function! s:TestResults_append(result) dict
  let tc_name = s:test_runner.current_testcase.name
  if !has_key(self.results, tc_name)
    let self.results[tc_name] = {}
  endif
  let tc_results = self.results[tc_name]
  let test = s:test_runner.current_test
  if !has_key(tc_results, test)
    let tc_results[test] = []
    let self.number_of.tests += 1
  endif
  call add(tc_results[test], a:result)
endfunction
call s:TestResults.method('append')

"---------------------------------------
" Success

let s:Success = unittest#oop#class#new('Success', s:SID)
let s:succ = s:Success.new()

"---------------------------------------
" Failure

let s:Failure = unittest#oop#class#new('Failure', s:SID)

function! s:Failure_initialize(reason, hint) dict
  let self.testcase = s:test_runner.current_testcase
  let self.test = s:test_runner.current_test
  let self.failpoint = expand('<sfile>')
  let self.assert = matchstr(self.failpoint, '\.\.\zsassert#\w\+\ze\.\.')
  let self.reason = a:reason
  let self.hint = (type(a:hint) == type("") ? a:hint : unittest#oop#string(a:hint))
endfunction
call s:Failure.method('initialize')

"---------------------------------------
" Error

let s:Error = unittest#oop#class#new('Error', s:SID)

function! s:Error_initialize() dict
  let self.testcase = s:test_runner.current_testcase
  let self.test = s:test_runner.current_test
  let self.throwpoint = v:throwpoint
  let self.exception = v:exception
endfunction
call s:Error.method('initialize')

" vim: filetype=vim
