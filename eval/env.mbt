///|
pub struct Env {
  symbols : @value.Symbols
  user : @value.Frame
}

///|
let native_add : Int = 1

///|
let native_subtract : Int = 2

///|
let native_multiply : Int = 3

///|
let native_append : Int = 4

///|
let native_find : Int = 5

///|
let native_pick : Int = 6

///|
let native_length : Int = 7

///|
let native_first : Int = 8

///|
let native_copy : Int = 9

///|
let native_insert : Int = 10

///|
let native_remove : Int = 11

///|
let native_func : Int = 12

///|
let native_does : Int = 13

///|
let native_make : Int = 14

///|
let native_reduce : Int = 15

///|
let native_do : Int = 16

///|
let native_mold : Int = 17

///|
let native_form : Int = 18

///|
let native_type : Int = 19

///|
let native_try : Int = 20

///|
let native_equal : Int = 21

///|
let native_not_equal : Int = 22

///|
let native_lesser : Int = 23

///|
let native_greater : Int = 24

///|
let native_if : Int = 25

///|
let native_either : Int = 26

///|
let native_return : Int = 27

///|
let native_while : Int = 28

///|
let native_until : Int = 29

///|
let native_loop : Int = 30

///|
let native_break : Int = 31

///|
let native_foreach : Int = 32

///|
let native_continue : Int = 33

///|
let native_not : Int = 34

///|
let native_and : Int = 35

///|
let native_or : Int = 36

///|
let native_any : Int = 37

///|
let native_all : Int = 38

///|
let native_case : Int = 39

///|
let native_switch : Int = 40

///|
let native_lesser_or_equal : Int = 41

///|
let native_greater_or_equal : Int = 42

///|
let native_strict_equal : Int = 43

///|
let native_next : Int = 44

///|
let native_back : Int = 45

///|
let native_head : Int = 46

///|
let native_tail : Int = 47

///|
let native_skip : Int = 48

///|
let native_at : Int = 49

///|
let native_index : Int = 50

///|
let native_head_q : Int = 51

///|
let native_tail_q : Int = 52

///|
let native_poke : Int = 53

///|
let native_get : Int = 54

///|
let native_set : Int = 55

///|
let native_unset : Int = 56

///|
let native_in : Int = 57

///|
let native_value_q : Int = 58

///|
let native_unset_q : Int = 59

///|
let native_bind : Int = 60

///|
let native_unbind : Int = 61

///|
let native_exit : Int = 62

///|
let native_unless : Int = 63

///|
let native_also : Int = 64

///|
let native_comment : Int = 65

///|
let native_catch : Int = 66

///|
let native_throw : Int = 67

///|
let native_compose : Int = 68

///|
let native_to : Int = 69

///|
let native_divide : Int = 70

///|
let native_remainder : Int = 71

///|
let native_power : Int = 72

///|
let native_negate : Int = 73

///|
let native_absolute : Int = 74

///|
let native_odd : Int = 75

///|
let native_even : Int = 76

///|
let native_negative : Int = 77

///|
let native_positive : Int = 78

///|
let native_zero : Int = 79

///|
let native_min : Int = 80

///|
let native_max : Int = 81

///|
let native_round : Int = 82

///|
let native_random : Int = 83

///|
let native_complement : Int = 84

///|
let native_shift : Int = 85

///|
let native_shift_left : Int = 86

///|
let native_shift_right : Int = 87

///|
let native_clear : Int = 88

///|
let native_take : Int = 89

///|
let native_reverse : Int = 90

///|
let native_swap : Int = 91

///|
let native_change : Int = 92

///|
let native_trim : Int = 93

///|
let native_select : Int = 94

///|
let native_sort : Int = 95

///|
let native_union : Int = 96

///|
let native_intersect : Int = 97

///|
let native_difference : Int = 98

///|
let native_exclude : Int = 99

///|
let native_unique : Int = 100

///|
let native_lowercase : Int = 101

///|
let native_uppercase : Int = 102

///|
let native_deline : Int = 103

///|
let native_enline : Int = 104

///|
let native_detab : Int = 105

///|
let native_entab : Int = 106

///|
let native_dehex : Int = 107

///|
let native_enhex : Int = 108

///|
let native_parse : Int = 109

///|
let native_load : Int = 110

///|
let native_save : Int = 111

///|
let native_module : Int = 112

///|
let native_import : Int = 113

///|
let native_closure : Int = 114

///|
let native_protect : Int = 115

///|
let native_unprotect : Int = 116

///|
let native_protected_q : Int = 117

///|
let native_open : Int = 118

///|
let native_close : Int = 119

///|
let native_read : Int = 120

///|
let native_write : Int = 121

///|
let native_query : Int = 122

///|
let native_call : Int = 123

///|
let native_now : Int = 124

///|
let native_wait : Int = 125

///|
let native_browse : Int = 126

///|
let native_quit : Int = 127

///|
let native_function : Int = 128

///|
let native_use : Int = 129

///|
let native_none_q : Int = 130

///|
let native_cause_error : Int = 131

///|
let native_series_q : Int = 132

///|
let native_clos : Int = 133

///|
let native_wrap : Int = 134

///|
let native_last : Int = 135

///|
let native_suffix_q : Int = 136

///|
let native_split_path : Int = 137

///|
let native_what_dir : Int = 138

///|
let native_change_dir : Int = 139

///|
let native_make_dir : Int = 140

///|
let native_clean_path : Int = 141

///|
let native_input : Int = 142

///|
let native_ask : Int = 143

///|
let native_confirm : Int = 144

///|
let native_wildcard : Int = 145

///|
let native_enbase : Int = 146

///|
let native_debase : Int = 147

///|
let native_checksum : Int = 148

///|
let native_compress : Int = 149

///|
let native_decompress : Int = 150

///|
let native_encloak : Int = 151

///|
let native_decloak : Int = 152

///|
let native_modify : Int = 153

///|
let native_update : Int = 154

///|
let native_decode : Int = 155

///|
let native_rsa_init : Int = 156

///|
let native_rsa : Int = 157

///|
let native_release : Int = 158

///|
let native_rc4 : Int = 159

///|
let native_dh_init : Int = 160

///|
let native_dh : Int = 161

///|
let native_ecdh : Int = 162

///|
let native_ecdsa : Int = 163

///|
let native_encode : Int = 164

///|
let native_encoding : Int = 165

///|
let native_words_of : Int = 166

///|
let native_mime_type : Int = 167

///|
let native_print : Int = 168

///|
let native_prin : Int = 169

///|
let native_same_q : Int = 170

///|
let native_put : Int = 171

///|
let native_collect : Int = 172

///|
let native_keep : Int = 173

///|
let native_get_env : Int = 174

///|
let native_set_env : Int = 175

///|
let native_split : Int = 176

///|
let native_true_q : Int = 177

///|
let native_false_q : Int = 178

///|
let native_values_of : Int = 179

///|
let native_square_root : Int = 180

///|
let native_map_each : Int = 181

///|
let native_repeat : Int = 182

///|
pub fn Env::new() -> Env {
  let env = Env::{ symbols: @value.Symbols::new(), user: @value.Frame::new(), }
  install(env, "true", @value.Logic(true))
  install(env, "false", @value.Logic(false))
  install(env, "none", @value.None)
  install(env, "newline", text_series("\n"))
  define_native(env, "+", 2, true, native_add)
  define_native(env, "-", 2, true, native_subtract)
  define_native(env, "*", 2, true, native_multiply)
  define_native(env, "append", 2, false, native_append)
  define_native(env, "find", 2, false, native_find)
  define_native(env, "pick", 2, false, native_pick)
  define_native(env, "length?", 1, false, native_length)
  define_native(env, "first", 1, false, native_first)
  define_native(env, "last", 1, false, native_last)
  define_native(env, "suffix?", 1, false, native_suffix_q)
  define_native(env, "split-path", 1, false, native_split_path)
  define_native(env, "what-dir", 0, false, native_what_dir)
  define_native(env, "change-dir", 1, false, native_change_dir)
  define_native(env, "get-env", 1, false, native_get_env)
  define_native(env, "set-env", 2, false, native_set_env)
  define_native(env, "split", 2, false, native_split)
  define_native(env, "true?", 1, false, native_true_q)
  define_native(env, "false?", 1, false, native_false_q)
  define_native(env, "make-dir", 1, false, native_make_dir)
  define_native(env, "clean-path", 1, false, native_clean_path)
  define_native(env, "input", 0, false, native_input)
  define_native(env, "ask", 1, false, native_ask)
  define_native(env, "confirm", 1, false, native_confirm)
  define_native(env, "wildcard", 2, false, native_wildcard)
  define_native(env, "enbase", 2, false, native_enbase)
  define_native(env, "debase", 2, false, native_debase)
  define_native(env, "checksum", 2, false, native_checksum)
  define_native(env, "compress", 2, false, native_compress)
  define_native(env, "decompress", 2, false, native_decompress)
  define_native(env, "encloak", 2, false, native_encloak)
  define_native(env, "decloak", 2, false, native_decloak)
  define_native(env, "modify", 3, false, native_modify)
  define_native(env, "update", 1, false, native_update)
  define_native(env, "decode", 2, false, native_decode)
  define_native(env, "encode", 2, false, native_encode)
  define_native(env, "encoding?", 1, false, native_encoding)
  define_native(env, "words-of", 1, false, native_words_of)
  define_native(env, "values-of", 1, false, native_values_of)
  define_native(env, "mime-type?", 1, false, native_mime_type)
  define_native(env, "rsa-init", 2, false, native_rsa_init)
  define_native(env, "rsa", 2, false, native_rsa)
  define_native(env, "release", 1, false, native_release)
  define_native(env, "rc4", 0, false, native_rc4)
  define_native(env, "dh-init", 2, false, native_dh_init)
  define_native(env, "dh", 1, false, native_dh)
  define_native(env, "ecdh", 1, false, native_ecdh)
  define_native(env, "ecdsa", 2, false, native_ecdsa)
  define_native(env, "copy", 1, false, native_copy)
  define_native(env, "insert", 2, false, native_insert)
  define_native(env, "remove", 1, false, native_remove)
  define_native(env, "func", 2, false, native_func)
  define_native(env, "does", 1, false, native_does)
  define_native(env, "make", 2, false, native_make)
  define_native(env, "reduce", 1, false, native_reduce)
  define_native(env, "do", 1, false, native_do)
  define_native(env, "mold", 1, false, native_mold)
  define_native(env, "form", 1, false, native_form)
  define_native(env, "print", 1, false, native_print)
  define_native(env, "prin", 1, false, native_prin)
  define_native(env, "same?", 2, false, native_same_q)
  define_native(env, "put", 3, false, native_put)
  define_native(env, "collect", 1, false, native_collect)
  define_native(env, "keep", 1, false, native_keep)
  define_native(env, "type?", 1, false, native_type)
  define_native(env, "try", 1, false, native_try)
  define_native(env, "=", 2, true, native_equal)
  define_native(env, "<>", 2, true, native_not_equal)
  define_native(env, "<", 2, true, native_lesser)
  define_native(env, ">", 2, true, native_greater)
  define_native(env, "if", 2, false, native_if)
  define_native(env, "either", 3, false, native_either)
  define_native(env, "return", 1, false, native_return)
  define_native(env, "while", 2, false, native_while)
  define_native(env, "until", 1, false, native_until)
  define_native(env, "loop", 2, false, native_loop)
  define_native(env, "break", 0, false, native_break)
  define_native(env, "foreach", 3, false, native_foreach)
  define_native(env, "map-each", 3, false, native_map_each)
  define_native(env, "repeat", 3, false, native_repeat)
  define_native(env, "continue", 0, false, native_continue)
  define_native(env, "not", 1, false, native_not)
  define_native(env, "and", 2, true, native_and)
  define_native(env, "or", 2, true, native_or)
  define_native(env, "any", 1, false, native_any)
  define_native(env, "all", 1, false, native_all)
  define_native(env, "case", 1, false, native_case)
  define_native(env, "switch", 2, false, native_switch)
  define_native(env, "<=", 2, true, native_lesser_or_equal)
  define_native(env, ">=", 2, true, native_greater_or_equal)
  define_native(env, "==", 2, true, native_strict_equal)
  define_native(env, "next", 1, false, native_next)
  define_native(env, "back", 1, false, native_back)
  define_native(env, "head", 1, false, native_head)
  define_native(env, "tail", 1, false, native_tail)
  define_native(env, "skip", 2, false, native_skip)
  define_native(env, "at", 2, false, native_at)
  define_native(env, "index?", 1, false, native_index)
  define_native(env, "head?", 1, false, native_head_q)
  define_native(env, "tail?", 1, false, native_tail_q)
  define_native(env, "series?", 1, false, native_series_q)
  define_native(env, "poke", 3, false, native_poke)
  define_native(env, "get", 1, false, native_get)
  define_native(env, "set", 2, false, native_set)
  define_native(env, "unset", 1, false, native_unset)
  define_native(env, "in", 2, false, native_in)
  define_native(env, "value?", 1, false, native_value_q)
  define_native(env, "none?", 1, false, native_none_q)
  define_native(env, "unset?", 1, false, native_unset_q)
  define_native(env, "bind", 2, false, native_bind)
  define_native(env, "unbind", 1, false, native_unbind)
  define_native(env, "exit", 0, false, native_exit)
  define_native(env, "unless", 2, false, native_unless)
  define_native(env, "also", 2, false, native_also)
  define_native(env, "comment", 1, false, native_comment)
  define_native(env, "catch", 2, false, native_catch)
  define_native(env, "throw", 2, false, native_throw)
  define_native(env, "compose", 1, false, native_compose)
  define_native(env, "to", 2, false, native_to)
  define_native(env, "/", 2, true, native_divide)
  define_native(env, "//", 2, true, native_remainder)
  define_native(env, "**", 2, true, native_power)
  define_native(env, "negate", 1, false, native_negate)
  define_native(env, "absolute", 1, false, native_absolute)
  define_native(env, "square-root", 1, false, native_square_root)
  define_native(env, "odd?", 1, false, native_odd)
  define_native(env, "even?", 1, false, native_even)
  define_native(env, "negative?", 1, false, native_negative)
  define_native(env, "positive?", 1, false, native_positive)
  define_native(env, "zero?", 1, false, native_zero)
  define_native(env, "minimum", 2, false, native_min)
  define_native(env, "maximum", 2, false, native_max)
  define_native(env, "round", 1, false, native_round)
  define_native(env, "random", 1, false, native_random)
  define_native(env, "complement", 1, false, native_complement)
  define_native(env, "shift", 2, false, native_shift)
  define_native(env, "<<", 2, true, native_shift_left)
  define_native(env, ">>", 2, true, native_shift_right)
  define_native(env, "clear", 1, false, native_clear)
  define_native(env, "take", 1, false, native_take)
  define_native(env, "reverse", 1, false, native_reverse)
  define_native(env, "swap", 2, false, native_swap)
  define_native(env, "change", 2, false, native_change)
  define_native(env, "trim", 1, false, native_trim)
  define_native(env, "select", 2, false, native_select)
  define_native(env, "sort", 1, false, native_sort)
  define_native(env, "union", 2, false, native_union)
  define_native(env, "intersect", 2, false, native_intersect)
  define_native(env, "difference", 2, false, native_difference)
  define_native(env, "exclude", 2, false, native_exclude)
  define_native(env, "unique", 1, false, native_unique)
  define_native(env, "lowercase", 1, false, native_lowercase)
  define_native(env, "uppercase", 1, false, native_uppercase)
  define_native(env, "deline", 1, false, native_deline)
  define_native(env, "enline", 1, false, native_enline)
  define_native(env, "detab", 1, false, native_detab)
  define_native(env, "entab", 1, false, native_entab)
  define_native(env, "dehex", 1, false, native_dehex)
  define_native(env, "enhex", 1, false, native_enhex)
  define_native(env, "parse", 2, false, native_parse)
  define_native(env, "load", 1, false, native_load)
  define_native(env, "save", 2, false, native_save)
  define_native(env, "module", 2, false, native_module)
  define_native(env, "import", 1, false, native_import)
  define_native(env, "closure", 2, false, native_closure)
  define_native(env, "clos", 2, false, native_clos)
  define_native(env, "protect", 1, false, native_protect)
  define_native(env, "unprotect", 1, false, native_unprotect)
  define_native(env, "protected?", 1, false, native_protected_q)
  define_native(env, "open", 1, false, native_open)
  define_native(env, "close", 1, false, native_close)
  define_native(env, "read", 1, false, native_read)
  define_native(env, "write", 2, false, native_write)
  define_native(env, "query", 1, false, native_query)
  define_native(env, "call", 1, false, native_call)
  define_native(env, "now", 0, false, native_now)
  define_native(env, "wait", 1, false, native_wait)
  define_native(env, "browse", 1, false, native_browse)
  define_native(env, "quit", 0, false, native_quit)
  define_native(env, "function", 2, false, native_function)
  define_native(env, "funct", 2, false, native_function)
  define_native(env, "use", 2, false, native_use)
  define_native(env, "wrap", 1, false, native_wrap)
  define_native(env, "cause-error", 3, false, native_cause_error)
  install(env, "unset!", @value.Type(@value.Unset))
  install(env, "none!", @value.Type(@value.None))
  install(env, "logic!", @value.Type(@value.Logic))
  install(env, "integer!", @value.Type(@value.Integer))
  install(env, "decimal!", @value.Type(@value.Decimal))
  install(env, "percent!", @value.Type(@value.Percent))
  install(env, "pair!", @value.Type(@value.Pair))
  install(env, "tuple!", @value.Type(@value.Tuple))
  install(env, "money!", @value.Type(@value.Money))
  install(env, "time!", @value.Type(@value.Time))
  install(env, "date!", @value.Type(@value.Date))
  install(env, "bitset!", @value.Type(@value.Bitset))
  install(env, "map!", @value.Type(@value.Map))
  install(env, "char!", @value.Type(@value.Char))
  install(env, "word!", @value.Type(@value.Word))
  install(env, "set-word!", @value.Type(@value.SetWord))
  install(env, "get-word!", @value.Type(@value.GetWord))
  install(env, "lit-word!", @value.Type(@value.LitWord))
  install(env, "refinement!", @value.Type(@value.Refinement))
  install(env, "string!", @value.Type(@value.String))
  install(env, "file!", @value.Type(@value.File))
  install(env, "email!", @value.Type(@value.Email))
  install(env, "url!", @value.Type(@value.Url))
  install(env, "tag!", @value.Type(@value.Tag))
  install(env, "issue!", @value.Type(@value.Issue))
  install(env, "binary!", @value.Type(@value.Binary))
  install(env, "block!", @value.Type(@value.Block))
  install(env, "paren!", @value.Type(@value.Paren))
  install(env, "path!", @value.Type(@value.Path))
  install(env, "set-path!", @value.Type(@value.SetPath))
  install(env, "datatype!", @value.Type(@value.Datatype))
  install(env, "function!", @value.Type(@value.Function))
  install(env, "closure!", @value.Type(@value.Closure))
  install(env, "op!", @value.Type(@value.Op))
  install(env, "object!", @value.Type(@value.Object))
  install(env, "port!", @value.Type(@value.Port))
  install(env, "handle!", @value.Type(@value.Handle))
  install(env, "vector!", @value.Type(@value.Vector))
  install(env, "image!", @value.Type(@value.Image))
  install(env, "struct!", @value.Type(@value.Struct))
  install(env, "typeset!", @value.Type(@value.Typeset))
  install(env, "event!", @value.Type(@value.Event))
  install(env, "utype!", @value.Type(@value.Utype))
  install_typesets(env)
  install(env, "module!", @value.Type(@value.Module))
  install(env, "error!", @value.Type(@value.Error))
  install(env, "sys", @value.Object(@value.Frame::new()))
  boot_system(env)
  boot_constants(env)
  boot_default(env)
  boot_series(env)
  boot_funcs(env)
  boot_series_helpers(env)
  boot_math(env)
  boot_types(env)
  boot_files(env)
  env
}

///|
fn install(env : Env, spelling : String, cell : @value.Cell) -> Unit {
  let sym = env.symbols.intern(spelling)
  let slot = env.user.ensure(sym)
  env.user.set(slot, cell) |> ignore
}

///|
fn define_native(
  env : Env,
  spelling : String,
  arity : Int,
  infix : Bool,
  code : Int,
) -> Unit {
  install(
    env,
    spelling,
    @value.Function(@value.Func::native(arity, infix, code)),
  )
}

///|
/// Transcodes `source` and binds words that already have a user slot.
pub fn load(env : Env, source : String) -> @value.Cell raise EvalError {
  match @scan.transcode(source, env.symbols) {
    Ok(cell) => @bind.bind(cell, env.user)
    Err(error) => raise EvalError::BadSource(error.id())
  }
}
