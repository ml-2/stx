#include <janet.h>

typedef struct jnt_stx_syntax {
  Janet name;
  int32_t line;
  int32_t column;
  Janet value;
} jnt_stx_syntax;

static int jnt_stx_syntax_gcmark(void *data, size_t len) {
  jnt_stx_syntax *stx = (jnt_stx_syntax *)data;
  janet_mark(stx->name);
  janet_mark(stx->value);
  return 0;
}

static void jnt_stx_syntax_marshal(void *data, JanetMarshalContext *ctx) {
  jnt_stx_syntax *stx = (jnt_stx_syntax *)data;
  janet_marshal_abstract(ctx, data);
  janet_marshal_janet(ctx, stx->name);
  janet_marshal_int(ctx, stx->line);
  janet_marshal_int(ctx, stx->column);
  janet_marshal_janet(ctx, stx->value);
}

static void *jnt_stx_syntax_unmarshal(JanetMarshalContext *ctx) {
  jnt_stx_syntax *stx = (jnt_stx_syntax *)janet_unmarshal_abstract(ctx, sizeof(jnt_stx_syntax));
  stx->name = janet_unmarshal_janet(ctx);
  stx->line = janet_unmarshal_int(ctx);
  stx->column = janet_unmarshal_int(ctx);
  stx->value = janet_unmarshal_janet(ctx);
  return stx;
}

static void jnt_stx_syntax_tostring(void *data, JanetBuffer *buffer) {
  jnt_stx_syntax *stx = (jnt_stx_syntax *)data;
  janet_buffer_push_cstring(buffer, "\"");
  janet_to_string_b(buffer, stx->name);
  janet_buffer_push_cstring(buffer, "\" L");
  janet_to_string_b(buffer, janet_wrap_integer(stx->line));
  janet_buffer_push_cstring(buffer, " C");
  janet_to_string_b(buffer, janet_wrap_integer(stx->column));
  janet_buffer_push_cstring(buffer, " ");
  janet_formatb(buffer, "%v", stx->value);
}

#define JNT_STX_CMP(x, y) (x > y) ? -1 : (x < y)
static int jnt_stx_syntax_compare(void *stx0, void *stx1) {
  jnt_stx_syntax *left = (jnt_stx_syntax *) stx0;
  jnt_stx_syntax *right = (jnt_stx_syntax *) stx1;
  int result;
  result = janet_compare(left->name, right->name);
  if (result != 0)
    return result;
  result = JNT_STX_CMP(left->line, right->line);
  if (result != 0)
    return result;
  result = JNT_STX_CMP(left->column, right->column);
  if (result != 0)
    return result;
  return janet_compare(left->value, right->value);
}

static int32_t jnt_stx_syntax_hash(void *v_stx, size_t size) {
  jnt_stx_syntax *stx = (jnt_stx_syntax *) v_stx;
  return janet_hash(stx->name)
    ^ janet_hash(janet_wrap_integer(stx->line))
    ^ janet_hash(janet_wrap_integer(stx->column))
    ^ janet_hash(stx->value);
}

static const JanetAbstractType jnt_stx_syntax_type = {
  .name = "stx",
  .gc = NULL,
  .gcmark = jnt_stx_syntax_gcmark,
  .get = NULL,
  .put = NULL,
  .marshal = jnt_stx_syntax_marshal,
  .unmarshal = jnt_stx_syntax_unmarshal,
  .tostring = jnt_stx_syntax_tostring,
  .compare = jnt_stx_syntax_compare,
  .hash = jnt_stx_syntax_hash,
  .next = NULL,
  .call = NULL,
  .length = NULL,
  .bytes = NULL,
};

static jnt_stx_syntax *jnt_stx_new_syntax(Janet name, int32_t line, int32_t column, Janet value) {
  jnt_stx_syntax *stx = (jnt_stx_syntax *)janet_abstract(&jnt_stx_syntax_type, sizeof(jnt_stx_syntax));
  stx->name = name;
  stx->line = line;
  stx->column = column;
  stx->value = value;
  return stx;
}

static Janet jnt_stx_syntax_new(int32_t argc, Janet *argv) {
  janet_fixarity(argc, 4);
  jnt_stx_syntax *stx = jnt_stx_new_syntax(
      argv[0], janet_getinteger(argv, 1), janet_getinteger(argv, 2), argv[3]);
  return janet_wrap_abstract(stx);
}

static Janet jnt_stx_syntax_name(int32_t argc, Janet *argv) {
  janet_fixarity(argc, 1);
  jnt_stx_syntax *stx = (jnt_stx_syntax *)janet_getabstract(argv, 0, &jnt_stx_syntax_type);
  return stx->name;
}

static Janet jnt_stx_syntax_line(int32_t argc, Janet *argv) {
  janet_fixarity(argc, 1);
  jnt_stx_syntax *stx = (jnt_stx_syntax *)janet_getabstract(argv, 0, &jnt_stx_syntax_type);
  return janet_wrap_integer(stx->line);
}

static Janet jnt_stx_syntax_column(int32_t argc, Janet *argv) {
  janet_fixarity(argc, 1);
  jnt_stx_syntax *stx = (jnt_stx_syntax *)janet_getabstract(argv, 0, &jnt_stx_syntax_type);
  return janet_wrap_integer(stx->column);
}

static Janet jnt_stx_syntax_value(int32_t argc, Janet *argv) {
  janet_fixarity(argc, 1);
  jnt_stx_syntax *stx = (jnt_stx_syntax *)janet_getabstract(argv, 0, &jnt_stx_syntax_type);
  return stx->value;
}

static const JanetReg cfuns[] = {
  { "new", jnt_stx_syntax_new,
    "(stx/new name line column)\n"
    "\n\n"
    "Creates a new syntax object."
  },
  { "name", jnt_stx_syntax_name,
    "(stx/name stx)\n"
    "\n\n"
    "Returns the name of the syntax object."
  },
  { "line", jnt_stx_syntax_line,
    "(stx/line stx)\n"
    "\n\n"
    "Returns the line number of the syntax object."
  },
  { "column", jnt_stx_syntax_column,
    "(stx/column stx)\n"
    "\n\n"
    "Returns the column number of the syntax object."
  },
  { "value", jnt_stx_syntax_value,
    "(stx/value stx)\n"
    "\n\n"
    "Returns the value contained in the syntax object."
  },
  { NULL, NULL, NULL }
};

JANET_MODULE_ENTRY(JanetTable *env) {
  janet_cfuns(env, "stx", cfuns);
  janet_register_abstract_type(&jnt_stx_syntax_type);
}

