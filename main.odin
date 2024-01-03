package SimpleForth

import "core:fmt"
import "core:mem"
import "core:os"
import "core:slice"
import "core:strconv"
import "core:strings"
import "core:unicode"
import "core:unicode/utf8"

Forth_value :: struct {
    value: int,
}

Forth_token :: union {
    Forth_value,
    Forth_word_token,
}

Forth_word_token :: struct {
    name: string,
    body: union {
        Forth_builtin_word,
        []Forth_token,
    },
}

Forth_builtin_word :: enum {
    add,
    dump,
}

Word_dictionnary :: #type map[string]union {
    Forth_builtin_word,
    []Forth_token,
}

word_dict: Word_dictionnary

@(init)
init_word_dict :: proc() {
    word_dict = make(Word_dictionnary)
    #assert(len(Forth_builtin_word) == 2, "Forgot to add builtin word to init")
    word_dict["+"] = Forth_builtin_word.add
    word_dict["."] = Forth_builtin_word.dump
}

main :: proc() {
    data, ok := os.read_entire_file("forth-files/test.4")
    if !ok do panic("failed to open file")

    forth_file := string(data)
    fmt.println("--------")
    //TODO: each string word will need to hold line and column info
    words_str, err := strings.fields(forth_file)
    if err != .None do panic("error in parsing words")

    //make the lexer
    tokens := make([dynamic]Forth_token)
    for word in words_str {
        word := strings.trim_right_space(word)
        //NOTE: this is very dumb, only need to do things with ascii stuff
        word_runes := utf8.string_to_runes(word, context.temp_allocator)
        /* assert(len(word_runes) == 1) */
        switch {
        case unicode.is_digit(word_runes[0]):
            x := strconv.atoi(word)
            forth_int := Forth_value{x}
            append(&tokens, forth_int)
        case:
            //NOTE: assume all words are builtin for now
            forth_word := Forth_word_token{word, word_dict[word]}
            append(&tokens, forth_word)
        }
    }

    fmt.println(tokens)
    fmt.println("--------")
    stack := make([dynamic]int)
    eval_program :: proc(tokens: []Forth_token, stack: ^[dynamic]int) {
        for token in tokens {
            switch it in token {
            case Forth_value:
                append(stack, it.value)

            case Forth_word_token:
                switch word_type in it.body {
                case Forth_builtin_word:
                    switch word_type {
                    case .add:
                        assert(len(stack) >= 2)
                        result := stack[len(stack) - 1] + stack[len(stack) - 2]
                        ordered_remove(stack, len(stack) - 1)
                        ordered_remove(stack, len(stack) - 1)
                        append(stack, result)
                    case .dump:
                        fmt.print(slice.last(stack[:]))
                        //pop last element from the stack
                        ordered_remove(stack, len(stack) - 1)
                    }
                case []Forth_token:
                    panic("not implemented")
                }
            }
        }
    }
    eval_program(tokens[:], &stack)
}
