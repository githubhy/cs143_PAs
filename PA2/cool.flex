/*
 *  The scanner definition for COOL.
 *  Stuff enclosed in %{ %} in the first section is copied verbatim to the
 *  output, so headers and global definitions are placed here to be visible
 * to the code in the file.  Don't remove anything that was here initially
 */

%x COMMENT
%x STRING STR_TO_END
%x REACH_EOF_IN_STATE

%option noyywrap nodefault
/* for yy_push/pop_state() */
%option stack

%{
#include <cool-parse.h>
#include <stringtab.h>
#include <utilities.h>

/* The compiler assumes these identifiers. */
#define yylval cool_yylval
#define yylex  cool_yylex

/* Max size of string constants */
#define MAX_STR_CONST 1025
#define YY_NO_UNPUT   /* keep g++ happy */

extern FILE *fin; /* we read from this file */

/* define YY_INPUT so we read from the FILE fin:
 * This change makes it possible to use this scanner in
 * the Cool compiler.
 */
#undef YY_INPUT
#define YY_INPUT(buf,result,max_size) \
	if ( (result = fread( (char*)buf, sizeof(char), max_size, fin)) < 0) \
	YY_FATAL_ERROR( "read() in flex scanner failed");

char string_buf[MAX_STR_CONST]; /* to assemble string constants */
char *string_buf_ptr;

extern int curr_lineno;
extern int verbose_flag;

extern YYSTYPE cool_yylval;

/*
 *  Add Your own definitions here
 */
#define yyerror(sTR) do{\
	yylval.error_msg = strdup(sTR);\
	return ERROR;\
}while(0)

#define strlenchk(lEN) do{\
        if (++lEN >= /* should leave a space for '\0' */ MAX_STR_CONST) {\
		yy_push_state(STR_TO_END);\
		yyerror("String constant too long");\
	}\
}while(0)

static int str_len;
static int comment_nesting;

%}

/*
 * Define names for regular expressions here.
 */

DARROW          =>

%%

 /*
 *  Nested comments
 */
"--".*          	;
"(*"            	{ yy_push_state(COMMENT); comment_nesting = 1; } 
"*)"            	{ yyerror("Unmatched *)"); }
<COMMENT>{
	"*)"		{ if (--comment_nesting == 0) yy_pop_state(); }
	"(*"		{ comment_nesting++; }
	\n		{ curr_lineno++; }
	<<EOF>> 	{ yy_push_state(REACH_EOF_IN_STATE); yyerror("EOF in comment"); }
	.		;
}

 /*
 *  The multiple-character operators.
 */
{DARROW}		{ return (DARROW); }

 /*
 * Keywords are case-insensitive except for the values true and false,
 * which must begin with a lower-case letter.
 */
[0-9]+			{ yylval.symbol = inttable.add_string(yytext); return INT_CONST; }
(?i:class)		{ return CLASS; }
(?i:if)			{ return IF; }
(?i:else)		{ return ELSE; }
(?i:fi)			{ return FI; }
(?i:in)			{ return IN; }
(?i:inherits)		{ return INHERITS; }
(?i:let)		{ return LET; }
(?i:loop)		{ return LOOP; }
(?i:pool)		{ return POOL; }
(?i:then)		{ return THEN; }
(?i:while)		{ return WHILE; }
(?i:case)		{ return CASE; }
(?i:esac)		{ return ESAC; }
(?i:of)			{ return OF; }
(?i:new)		{ return NEW; }
(?i:isvoid)		{ return ISVOID; }
(?i:not)		{ return NOT; }
t(?i:rue)		{ yylval.boolean = 1; return BOOL_CONST; }
f(?i:alse)		{ yylval.boolean = 0; return BOOL_CONST; }
[A-Z][A-Za-z0-9_]*	{ yylval.symbol = idtable.add_string(yytext); return TYPEID; }
[a-z][A-Za-z0-9_]*	{ yylval.symbol = idtable.add_string(yytext); return OBJECTID; }
"<-"			{ return ASSIGN; }
"<="			{ return LE; }
 /* Ignore LET_STMT */
[{}()@.,:;+\-*/~<=]     { return yytext[0]; } /* Either put the '-' to the very beginning or the end, or escape it */



 /*
 *  String constants (C syntax)
 *  Escape sequence \c is accepted for all characters c. Except for 
 *  \n \t \b \f, the result is c.
 *
 */
\"			{ yy_push_state(STRING); string_buf_ptr = string_buf; str_len = 0; }
<STRING>{
	\"		{ yy_pop_state(); *string_buf_ptr = '\0'; yylval.symbol = stringtable.add_string(string_buf); return STR_CONST; }

	<<EOF>>		{ yy_push_state(REACH_EOF_IN_STATE); yyerror("EOF in string constant"); }
	\0		{ yy_push_state(STR_TO_END); yyerror("String contains null character");}
	\n		{ yy_pop_state(); curr_lineno++; yyerror("Unterminated string constant"); }
	\\\0		{ yy_push_state(STR_TO_END); yyerror("String contains escaped null character"); }

	\\b		{ *string_buf_ptr++ = '\b'; strlenchk(str_len); }
	\\t		{ *string_buf_ptr++ = '\t'; strlenchk(str_len); }
	\\n		{ *string_buf_ptr++ = '\n'; strlenchk(str_len); }
	\\f		{ *string_buf_ptr++ = '\f'; strlenchk(str_len); }
	\\\n		{ *string_buf_ptr++ = '\n'; curr_lineno++; strlenchk(str_len); }
	\\.		{ *string_buf_ptr++ = yytext[1]; strlenchk(str_len); }
	.		{ *string_buf_ptr++ = yytext[0]; strlenchk(str_len); }
}

<STR_TO_END>{
	\\\n		;
	\n|\"		{ yy_pop_state(); yy_pop_state(); }
	.		;
}

 /* White spaces and other extraneous characters */
[ \f\r\t\v]		;
\n			{ curr_lineno++; }
.			{ yyerror(yytext); } /* Error Handling */

 /* Specail processing EOF: When flex matches EOF, it will not swallow it, while it keeps matching EOF again and again.
  * A zero should be returned to make the matching terminated.
  */
<REACH_EOF_IN_STATE><<EOF>>	{ yy_pop_state(); return 0; }

%%

