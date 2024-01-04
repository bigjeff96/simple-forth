package stack

import "core:slice"
import "core:mem"
import "core:container"
import "core:fmt"

//TODO: implement a stack
push :: proc(stack: ^[dynamic]$E, value: E) {
    append(stack, value)
}

pop :: #force_inline proc(stack: ^[dynamic]$E) {
    if len(stack) == 0 {
	panic("stack is empty")
    }
    unordered_remove(stack, len(stack) - 1)
}

top :: #force_inline proc(stack: [dynamic]$E) -> E {
    if len(stack) == 0 {
	panic("stack is empty")
    }
    return stack[len(stack) - 1]
}

get :: #force_inline proc(stack: [dynamic]$E, index_from_top: int) -> E {

    if index_from_top >= 0 || abs(index_from_top) > len(stack) {
	panic("index out of bounds")
    }

    return stack[len(stack) + index_from_top]
}

set :: #force_inline proc(stack: ^[dynamic]$E, index_from_top: int, value: E) {

    if index_from_top >= 0 || abs(index_from_top) > len(stack) {
	panic("index out of bounds")
    }

    stack[len(stack) + index_from_top] = value
}
