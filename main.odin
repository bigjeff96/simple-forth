package SimpleForth

import "core:fmt"
import "core:log"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:time"
import "core:unicode"
import "core:unicode/utf8"

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
    body: ^Forth_builtin_or_word,
}

Forth_builtin_word :: enum {
    add,
    sub,
    dump,
    jmp,
    jeq,
    jle,
    dublicate,
    swap,
    over,
    rotate,
    drop,
    comment_start,
    comment_end,
    end,
}

Forth_builtin_or_word :: union {
    Forth_builtin_word,
    []Forth_token,
}

Forth_program :: struct {
    tokens: [dynamic]Forth_token,
    stack:  [dynamic]int,
    ip:     int,
}

Word_dictionnary :: #type map[string]Forth_builtin_or_word

word_dict: Word_dictionnary

@(init)
init_word_dict :: proc() {
    word_dict = make(Word_dictionnary)
    #assert(len(Forth_builtin_word) == 14, "Forgot to add builtin words to init")
    word_dict["-"] = .sub
    word_dict["+"] = .add
    word_dict["."] = .dump
    word_dict["jmp"] = .jmp
    word_dict["jeq"] = .jeq
    word_dict["jle"] = .jle
    word_dict["dup"] = .dublicate
    word_dict["drop"] = .drop
    word_dict["rotate"] = .rotate
    word_dict["swap"] = .swap
    word_dict["over"] = .over
    word_dict["("] = .comment_start
    word_dict[")"] = .comment_end
    word_dict["end"] = .end
}

DEBUG :: false

main :: proc() {

    when DEBUG {
        context.logger = log.create_console_logger(log.Level.Debug)
    } else {
        context.logger = log.create_console_logger(log.Level.Info)
    }

    data, ok := os.read_entire_file("forth-files/recursive.4")
    if !ok do panic("failed to open file")

    forth_file := string(data)
    log.debugf("--------")
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

    Compile_word :: struct {
        compiling: bool,
        word:      string,
        body:      [dynamic]Forth_token,
    }
    compile_word: Compile_word

    make_tokens :: proc(
        words_str: []string,
        tokens: ^[dynamic]Forth_token,
        word_dict: ^Word_dictionnary,
        compile_word: ^Compile_word,
    ) -> int {

        comment_flag := false
        //make the lexer
        //TODO: Be able to define functions
        id := 0
        for id < len(words_str) {
            defer id += 1

            word := words_str[id]
            word = strings.trim_right_space(word)
            //NOTE: this is very dumb, only need to do things with ascii stuff
            word_runes := utf8.string_to_runes(word, context.temp_allocator)
            switch {

            case unicode.is_digit(word_runes[0]) && !comment_flag:
                x := strconv.atoi(word)
                forth_int := Forth_value{x}
                append(tokens, forth_int)
            case word == "(":
                comment_flag = true
            //skip comments

            case word == ")":
                comment_flag = false
            //skip comments

            case word == ":" && !comment_flag:
                new_word_compile: Compile_word
                new_word_compile.compiling = true
                id += 1
                new_word_compile.word = words_str[id]
                word_dict[new_word_compile.word] = nil
                tokens_for_new_word := make([dynamic]Forth_token)

                //do a recursive call here
                new_id := make_tokens(words_str[id + 1:], &tokens_for_new_word, word_dict, &new_word_compile)
                id += new_id + 1

            case word == ";" && !comment_flag:
                //update the dictionnary with new word
                compile_word.body = tokens^
                word_dict[compile_word.word] = compile_word.body[:]
                return id

            case !comment_flag:
                //NOTE: assume all words are builtin for now
                thing, ok := word_dict[word]
                if !ok {
                    log.error("word not found: ", word)
                    os.exit(0)
                }
                forth_word := Forth_word_token{word, &word_dict[word]}
                append(tokens, forth_word)
            }
        }

        return 0
    }

    make_tokens(words_str, &tokens, &word_dict, &compile_word)

    log.debugf("tokens: %v", tokens)
    log.debugf("--------")

    // "walk the tree"
    eval_program :: proc(stack: ^[dynamic]int, tokens: []Forth_token) {
        using stack_core
        // using program
        ip := 0
        ticks := 0
        for ip < len(tokens) {
            defer {
                ip += 1
                ticks += 1
            }
            token := &tokens[ip]
            log.debugf("stack: %v token: %v", stack^, token)

            switch it in token {
            case Forth_value:
                append(stack, it.value)

            case Forth_comment:
            //skip comments
            case Forth_word_token:
                switch word_type in it.body {
                case Forth_builtin_word:
                    switch word_type {
                    case .comment_start:
                    case .comment_end:
                    case .end:
                    case .sub:
                        assert(len(stack) >= 2)
                        a := get(stack, -2)
                        b := get(stack, -1)
                        result := a - b
                        pop(stack)
                        pop(stack)
                        push(stack, result)
                    case .add:
                        assert(len(stack) >= 2)
                        result := get(stack, -1) + get(stack, -2)
                        pop(stack)
                        pop(stack)
                        push(stack, result)
                    case .dump:
                        log.info(slice.last(stack[:]))
                        pop(stack)
                    case .dublicate:
                        assert(len(stack) >= 1)
                        push(stack, top(stack))
                    case .drop:
                        pop(stack)
                    case .rotate:
                        assert(len(stack) >= 3)
                        a := get(stack, -1)
                        b := get(stack, -2)
                        c := get(stack, -3)
                        set(stack, -1, c)
                        set(stack, -2, a)
                        set(stack, -3, b)
                    case .jmp:
                        address := top(stack)
                        pop(stack)
                        assert(address >= 0 && address < len(tokens))
                        ip = address - 1 //NOTE: to compensate for the defer + 1
                    case .jeq:
                        assert(len(stack) >= 2)
                        condition := get(stack, -2)
                        if condition == 0 {
                            address := get(stack, -1)
                            assert(address >= 0 && address < len(tokens))
                            ip = address - 1 //NOTE: to compensate for the defer + 1
                        }
                        pop(stack)
                        pop(stack)
                    case .jle:
                        assert(len(stack) >= 2)
                        condition := get(stack, -2)
                        if condition <= 0 {
                            address := get(stack, -1)
                            assert(address >= 0 && address < len(tokens))
                            ip = address - 1 //NOTE: to compensate for the defer + 1
                        }
                        pop(stack)
                        pop(stack)
                    case .swap:
                        assert(len(stack) >= 2)
                        a := get(stack, -1)
                        b := get(stack, -2)
                        set(stack, -1, b)
                        set(stack, -2, a)

                    case .over:
                        assert(len(stack) >= 2)
                        push(stack, get(stack, -2))
                    }
                case []Forth_token:
                    eval_program(stack, word_type)
                }
            }
        }
    }
    eval_program(stack = &program.stack, tokens = program.tokens[:])
}
