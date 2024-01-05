package SimpleForth

import "core:fmt"
import "core:mem"
import "core:os"
import "core:time"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

// this is a stupid comment about nothing

import stack_core "stack"

Forth_value :: struct {
    value: int,
}

Forth_comment :: struct {
    comment: string,
}

Forth_token :: union {
    Forth_value,
    Forth_word_token,
    Forth_comment,
}

Forth_word_token :: struct {
    name: string,
    body: Forth_builtin_or_word,
}

Forth_builtin_word :: enum {
    add,
    sub,
    dump,
    branch,
    branch_if_zero,
    dublicate,
    swap,
    over,
}

Forth_builtin_or_word :: union {
    Forth_builtin_word,
    []Forth_token,
}

Forth_program :: struct {
    tokens: [dynamic]Forth_token,
    stack: [dynamic]int,
    ip: int,
}

Word_dictionnary :: #type map[string]Forth_builtin_or_word

word_dict: Word_dictionnary

@(init)
init_word_dict :: proc() {
    word_dict = make(Word_dictionnary)
    #assert(len(Forth_builtin_word) == 8, "Forgot to add builtin words to init")
    word_dict["-"] = Forth_builtin_word.sub
    word_dict["+"] = Forth_builtin_word.add
    word_dict["."] = Forth_builtin_word.dump
    word_dict["branch"] = Forth_builtin_word.branch
    word_dict["branch?"] = Forth_builtin_word.branch_if_zero
    word_dict["dup"] = Forth_builtin_word.dublicate
    word_dict["swap"] = Forth_builtin_word.swap
    word_dict["over"] = Forth_builtin_word.over
}

main :: proc() {
    data, ok := os.read_entire_file("forth-files/sub.4")
    if !ok do panic("failed to open file")

    forth_file := string(data)
    fmt.println("--------")
    //TODO: each string word will need to hold line and column info
    words_str, err := strings.fields(forth_file)
    if err != .None do panic("error in parsing words")

    program: Forth_program
    init_forth_program :: proc(program: ^Forth_program) {
	program.tokens = make([dynamic]Forth_token)
	program.stack = make([dynamic]int)
	program.ip = 0
    }
    init_forth_program(&program)
    using program

    comment_marker := false
    //make the lexer
    for word in words_str {
        word := strings.trim_right_space(word)
        //NOTE: this is very dumb, only need to do things with ascii stuff
        word_runes := utf8.string_to_runes(word, context.temp_allocator)
        switch {
        case unicode.is_digit(word_runes[0]) && !comment_marker:
            x := strconv.atoi(word)
            forth_int := Forth_value{x}
            append(&tokens, forth_int)
        case len(word) >= 1 && word[:1] == "(" && !(word[len(word) - 1:] == ")"):
	    comment_marker = true
	    //skip comments

	case len(word) >= 1 && word[len(word) - 1:] == ")":
	    comment_marker = false
	    //skip comments

	case !comment_marker:
            //NOTE: assume all words are builtin for now
            forth_word := Forth_word_token{word, word_dict[word]}
            append(&tokens, forth_word)
        }
    }

    fmt.println(tokens)
    fmt.println("--------")
    
    // "walk the tree"
    eval_program :: proc(program: ^Forth_program) {
	using stack_core
	using program

	program.ip = 0
	ticks := 0
	for ip < len(tokens) {
	    defer {
		ip += 1
		ticks += 1
		time.sleep(auto_cast (50000000))
	    }
	    token := &tokens[ip]

	    if ticks > 100 {
		break
	    }

	    switch it in token {
	    case Forth_value:
                append(&stack, it.value)

	    case Forth_comment:
		//skip comments
	    case Forth_word_token:
                switch word_type in it.body {
                case Forth_builtin_word:
		    switch word_type {
		    case .sub:
			assert(len(stack) >= 2)
			a := get(stack, -2)
			b := get(stack, -1)
			result := a - b
			pop(&stack)
			pop(&stack)
			push(&stack, result)
		    case .add:
                        assert(len(stack) >= 2)
                        result := get(stack,-1) + get(stack,-2)
			pop(&stack)
			pop(&stack)
			push(&stack, result)
		    case .dump:
                        fmt.println(slice.last(stack[:]))
                        pop(&stack)
		    case .dublicate:
			assert(len(stack) >= 1)
			push(&stack, top(stack))
		    case .branch:
			address := top(stack)
			pop(&stack)
			assert(address >= 0 && address < len(tokens))
			ip = address - 1 //NOTE: to compensate for the defer + 1
		    case .branch_if_zero:
			assert(len(stack) >= 2)
			condition := top(stack)
			if condition == 0 {
			    address := get(stack, -2)
			    assert(address >= 0 && address < len(tokens))
			    ip = address - 1 //NOTE: to compensate for the defer + 1
			}
		    case .swap:
			assert(len(stack) >= 2)
			a := get(stack, -1)
			b := get(stack, -2)
			set(&stack, -1, b)
			set(&stack, -2, a)

		    case .over:
			assert(len(stack) >= 2)
			push(&stack, get(stack, -2))
		    }
                case []Forth_token:
		    unimplemented("user defined words")
                }
	    }
	}
    }
    eval_program(&program)
}
