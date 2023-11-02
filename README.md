[![Automated tests for Continuous integration](https://github.com/laurentalacoque/vim-unittest/actions/workflows/main.yml/badge.svg)](https://github.com/laurentalacoque/vim-unittest/actions/workflows/main.yml)
# vim-unittest
Unit Testing Framework for Vim scripts

unittest.vim is a unit testing framework for Vim script. It helps
	you to test commands and functions defined in your Vim scripts. You
	can write tests of not only global commands and functions but also
	script-locals in the manner of xUnit frameworks.

# Authors & changes
vim-unittest was written by [h1mesuke](https://github.com/h1mesuke).
[laurentalacoque](https://github.com/laurentalacoque) only added the following tiny changes :

- Fixed initialization bug that prevented tests to be run
- Assertions now return 1 on success and 0 on failure
- bin/vunit program now return 0 on success and 1 if the errors/failures count is different from 0
- Added `tc.pass()` and `tc.fail({hint})` convenience functions


# Basic usage
1. Make a new test case file.

```bash
		$ vim test_something.vim
```

**NOTE** Basename of a test case file *MUST* start with "test_" or "tc_".

2. Create a new TestCase object at your "test_something.vim".
```vim
		let s:tc = unittest#testcase#new("Something")
```

`unittest#testcase#new()` returns a new TestCase object. It's first argument will be used as a caption in the report of the test results.

3. Define test functions as the TestCase's methods.
```vim
		function! s:tc.test_one()
		  call self.assert(1)
		endfunction

		function! s:tc.one_should_be_true()
		  call self.assert(1)
		endfunction
```

Names of test functions MUST start with `test_` or contain `should`.

4. Use assertions in the test functions to describe your expectations.

See `:help unittest-assertions` help page in `vim`.

5. Run the tests.
```vim
		:UnitTest
```
See `:help unittest-how-to-run`, `:help :UnitTest`.



