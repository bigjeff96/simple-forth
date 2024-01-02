package SimpleForth

import "core:fmt"
import "core:slice"
import "core:os"
import "core:strconv"
import "core:strings"
import "core:unicode/utf8"
import "core:unicode"

Forth_integer :: struct {
    value: int,
}
Forth_add :: struct {}
Forth_dump :: struct {}

Forth_word :: union {
    Forth_integer,
    Forth_add,
    Forth_dump,
}


main :: proc() {
    data, ok := os.read_entire_file("forth-files/test.4")
    if !ok do panic("failed to open file")

    forth_file := string(data)
    fmt.println(forth_file)

    fmt.println("--------")
    words_strings, _ := strings.split(forth_file, " ")

    //make the lexer
    //TODO: will def need to rework this
    //TODO: correctly remove whitespace
    //TODO: show errors and stuff when we have failure in sparcing
    tokens := make([dynamic]Forth_word)

    for word in words_strings {
	word := strings.trim_right_space(word)
	word_runes := utf8.string_to_runes(word, context.temp_allocator)
	/* assert(len(word_runes) == 1) */
	switch {
	case unicode.is_digit(word_runes[0]):
	    x := strconv.atoi(word)
	    forth_int := Forth_integer{x}
	    append(&tokens, forth_int)

	case word == "+":
	    append(&tokens, Forth_add{})

	case word == ".":
	    append(&tokens, Forth_dump{})
	}
    }
    stack := make([dynamic]int)
    eval_program :: proc(tokens: []Forth_word, stack: ^[dynamic]int) {
	for token in tokens {
	    switch it in token {
	    case Forth_integer:
		append(stack, it.value)

	    case Forth_add:
		assert(len(stack) >= 2)
		result := stack[len(stack) - 1] + stack[len(stack) - 2]
		ordered_remove(stack, len(stack) - 1)
		ordered_remove(stack, len(stack) - 1)
		append(stack, result)

	    case Forth_dump:
		fmt.println(slice.last(stack[:]))
		clear(stack)
	    }
	}
    }

    eval_program(tokens[:], &stack)
}
