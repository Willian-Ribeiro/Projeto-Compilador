header
{
	using StringBuilder				= System.Text.StringBuilder;
	using FileInfo 					= System.IO.FileInfo;
}

options
{
	language 	= "CSharp";	
	namespace	= "Kunle.CSharpParser";
}

/**
[The "BSD licence"]
Copyright (c) 2002-2005 Kunle Odutola
All rights reserved.

Redistribution and use in source and binary forms, with or without
modification, are permitted provided that the following conditions
are met:
1. Redistributions of source code must retain the above copyright
notice, this list of conditions and the following disclaimer.
2. Redistributions in binary form must reproduce the above copyright
notice, this list of conditions and the following disclaimer in the
documentation and/or other materials provided with the distribution.
3. The name of the author may not be used to endorse or promote products
derived from this software without specific prior written permission.

THIS SOFTWARE IS PROVIDED BY THE AUTHOR ``AS IS'' AND ANY EXPRESS OR
IMPLIED WARRANTIES, INCLUDING, BUT NOT LIMITED TO, THE IMPLIED WARRANTIES
OF MERCHANTABILITY AND FITNESS FOR A PARTICULAR PURPOSE ARE DISCLAIMED.
IN NO EVENT SHALL THE AUTHOR BE LIABLE FOR ANY DIRECT, INDIRECT,
INCIDENTAL, SPECIAL, EXEMPLARY, OR CONSEQUENTIAL DAMAGES (INCLUDING, BUT
NOT LIMITED TO, PROCUREMENT OF SUBSTITUTE GOODS OR SERVICES; LOSS OF USE,
DATA, OR PROFITS; OR BUSINESS INTERRUPTION) HOWEVER CAUSED AND ON ANY
THEORY OF LIABILITY, WHETHER IN CONTRACT, STRICT LIABILITY, OR TORT
(INCLUDING NEGLIGENCE OR OTHERWISE) ARISING IN ANY WAY OUT OF THE USE OF
THIS SOFTWARE, EVEN IF ADVISED OF THE POSSIBILITY OF SUCH DAMAGE.


/// <summary>
/// A Parser for the C# language (including preprocessors directives).
/// </summary>
///
/// <remarks>
/// <para>
/// The Parser defined below is based on the "C# Language Specification" as documented in 
/// the ECMA-334 standard dated December 2001.
/// </para>
///
/// <para>
/// One notable feature of this parser is that it can handle input that includes "normalized"
/// C# preprocessing directives. In the simplest sense, normalized C# preprocessing directives 
/// are directives that can be safely deleted from a source file without triggering any parsing 
/// errors due to incomplete statements etc.
/// </para>
///
/// <para>
/// The Abstract Syntax Tree that this parser constructs has special nodes that represents
//  all the C# preprocessor directives defined in the ECMA-334 standard.
/// </para>
///
/// <para>
/// History
/// </para>
///
/// <para>
/// 31-May-2002 kunle	  Started work in earnest
/// 09-Feb-2003 kunle     Separated Parser from the original combined Lexer/Parser grammar file<br/>
/// 20-Oct-2003 kunle     Removed STMT_LIST from inside BLOCK nodes. A BLOCK node now directly contains
///						  a list of statements. Finding the AST nodes that correspond to a selection
///						  should now be easier.<br/>
/// </para>
///
/// </remarks>

*/
class CSharpParser extends Parser;

options
{
	k								= 2;							// two tokens of lookahead
	importVocab						= CSharpLexer;
	exportVocab						= CSharp;
	buildAST						= true;
	ASTLabelType					= "ASTNode";
	//codeGenMakeSwitchThreshold		= 5;							// Some optimizations
	//codeGenBitsetTestThreshold		= 50;
	//defaultErrorHandler				= false;
	defaultErrorHandler				= true;
}

tokens
{
	COMPILATION_UNIT;
	USING_DIRECTIVES;
	USING_ALIAS_DIRECTIVE;
	USING_NAMESPACE_DIRECTIVE;
	GLOBAL_ATTRIBUTE_SECTIONS;
	GLOBAL_ATTRIBUTE_SECTION;
	ATTRIBUTE_SECTIONS;
	ATTRIBUTE_SECTION;
	ATTRIBUTE;
	QUALIFIED_IDENTIFIER;
	POSITIONAL_ARGLIST;
	POSITIONAL_ARG;
	NAMED_ARGLIST;
	NAMED_ARG;
	ARG_LIST;
	FORMAL_PARAMETER_LIST;
	PARAMETER_FIXED;
	PARAMETER_ARRAY;
	ATTRIB_ARGUMENT_EXPR;
	UNARY_MINUS;
	UNARY_PLUS;
	CLASS_BASE;
	STRUCT_BASE;
	INTERFACE_BASE;
	ENUM_BASE;
	TYPE_BODY;
	MEMBER_LIST;
	CONST_DECLARATOR;
	CTOR_DECL;
	STATIC_CTOR_DECL;
	DTOR_DECL;
	FIELD_DECL;
	METHOD_DECL;
	PROPERTY_DECL;
	INDEXER_DECL;
	UNARY_OP_DECL;	
	BINARY_OP_DECL;	
	CONV_OP_DECL;	
	
	TYPE;
	STARS;
	ARRAY_RANK;
	ARRAY_RANKS;
	ARRAY_INIT;
	VAR_INIT;
	VAR_INIT_LIST;
	VAR_DECLARATOR;
	LOCVAR_INIT;
	LOCVAR_INIT_LIST;
	LOCVAR_DECLS;
	LOCAL_CONST;
	
	EXPR;
	EXPR_LIST;
	MEMBER_ACCESS_EXPR;
	ELEMENT_ACCESS_EXPR;
	INVOCATION_EXPR;
	POST_INC_EXPR;
	POST_DEC_EXPR;
	PAREN_EXPR;
	OBJ_CREATE_EXPR;
	DLG_CREATE_EXPR;
	ARRAY_CREATE_EXPR;
	CAST_EXPR;

	PTR_ELEMENT_ACCESS_EXPR;
	PTR_INDIRECTION_EXPR;
	PTR_DECLARATOR;
	PTR_INIT;
	ADDRESS_OF_EXPR;
	
	MODIFIERS;
	NAMESPACE_BODY;	
	BLOCK;
	STMT_LIST;
	EMPTY_STMT;
	LABEL_STMT;
	EXPR_STMT;
	
	FOR_INIT;
	FOR_COND;
	FOR_ITER;
	
	SWITCH_SECTION;
	SWITCH_LABELS;
	SWITCH_LABEL;

	PP_DIRECTIVES;
	PP_EXPR;
	PP_MESSAGE;
	PP_BLOCK;
}

{
	//---------------------------------------------------------------------
	// PRIVATE DATA MEMBERS
	//---------------------------------------------------------------------
	private FileInfo fileinfo_;
		
	private bool NotExcluded(CodeMaskEnums codeMask, CodeMaskEnums construct)
	{
		return ((codeMask & construct) != 0 );
	}
	
	public override void setFilename(string filename)
	{
		base.setFilename(filename);
		fileinfo_ = new FileInfo(filename);
		((ASTNodeFactory) astFactory).FileInfo = fileinfo_;
	}

	private bool SingleLinePPDirectiveIsPredictedByLA(int lookAheadDepth)
	{
		if ((LA(lookAheadDepth) == PP_WARNING)  ||
			(LA(lookAheadDepth) == PP_ERROR)    ||
			(LA(lookAheadDepth) == PP_LINE)     ||
			(LA(lookAheadDepth) == PP_UNDEFINE) ||
			(LA(lookAheadDepth) == PP_DEFINE))
		{
			return true;
		}
		return false;
	}
	
	private bool PPDirectiveIsPredictedByLA(int lookAheadDepth)
	{
		if ((LA(lookAheadDepth) == PP_REGION)   ||
			(LA(lookAheadDepth) == PP_COND_IF)  ||
			(LA(lookAheadDepth) == PP_WARNING)  ||
			(LA(lookAheadDepth) == PP_ERROR)    ||
			(LA(lookAheadDepth) == PP_LINE)     ||
			(LA(lookAheadDepth) == PP_UNDEFINE) ||
			(LA(lookAheadDepth) == PP_DEFINE))
		{
			return true;
		}
		return false;
	}
	
	private bool IdentifierRuleIsPredictedByLA(int lookAheadDepth)
	{
		if ((LA(lookAheadDepth) == IDENTIFIER)       ||
			(LA(lookAheadDepth) == LITERAL_add)      ||
			(LA(lookAheadDepth) == LITERAL_remove)   ||
			(LA(lookAheadDepth) == LITERAL_get)      ||
			(LA(lookAheadDepth) == LITERAL_set)      ||
			(LA(lookAheadDepth) == LITERAL_assembly) ||
			(LA(lookAheadDepth) == LITERAL_field)    ||
			(LA(lookAheadDepth) == LITERAL_method)   ||
			(LA(lookAheadDepth) == LITERAL_module)   ||
			(LA(lookAheadDepth) == LITERAL_param)    ||
			(LA(lookAheadDepth) == LITERAL_property) ||
			(LA(lookAheadDepth) == LITERAL_type))
		{
			return true;
		}
		return false;
	}
	
	private bool TypeRuleIsPredictedByLA(int lookAheadDepth)
	{
		if ((LA(lookAheadDepth) == DOT)        ||
			(LA(lookAheadDepth) == VOID)       ||
			(LA(lookAheadDepth) == IDENTIFIER) ||
			(LA(lookAheadDepth) == INT)        ||
			(LA(lookAheadDepth) == BOOL)       ||
			(LA(lookAheadDepth) == STRING)     ||
			(LA(lookAheadDepth) == OBJECT)     ||
			(LA(lookAheadDepth) == BYTE)       ||
			(LA(lookAheadDepth) == CHAR)       ||
			(LA(lookAheadDepth) == DECIMAL)    ||
			(LA(lookAheadDepth) == DOUBLE)     ||
			(LA(lookAheadDepth) == FLOAT)      ||
			(LA(lookAheadDepth) == LONG)       ||
			(LA(lookAheadDepth) == SBYTE)      ||
			(LA(lookAheadDepth) == SHORT)      ||
			(LA(lookAheadDepth) == UINT)       ||
			(LA(lookAheadDepth) == ULONG)      ||
			(LA(lookAheadDepth) == USHORT))
		{
			return true;
		}
		return false;
	}
}

//=============================================================================
// Start of RULES
//=============================================================================

//
// C# LANGUAGE SPECIFICATION
//
// A.2 Syntactic grammar 
//
// The start rule for this grammar is 'compilationUnit'
//

//
// A.2.1 Basic concepts
//

nonKeywordLiterals
	:	"add"
	|	"remove"
	|	"get"
	|	"set"
	|	"assembly"
	|	"field"
	|	"method"
	|	"module"
	|	"param"
	|	"property"
	|	"type"
	;
	
identifier
	:	IDENTIFIER
	|	n:nonKeywordLiterals { #n.setType(IDENTIFIER); }
	;
	
qualifiedIdentifier
	:	identifier	
		(	options { greedy = true; } :
			DOT^ qualifiedIdentifier
		)?
	;

/*
//
// A.2.2 Types
//
*/
type!
	{
		ASTNode typeBase  = null; 
		ASTNode starsBase = #[STARS, "STARS"]; 
	}
	:	(
			( p:predefinedTypeName { typeBase = #p; } | q:qualifiedIdentifier { typeBase = #q; } )	// typeName
			(
				s1:STAR						// pointerType
				{
					#starsBase.addChildEx(#s1); 
				}
			)*

		|	v:VOID s2:STAR
			{
				#starsBase.addChildEx(#s2);
			  	typeBase = #v;
			}
		)
		r:rankSpecifiers 						//	arrayType := nonArrayType rankSpecifiers
		{ ## = #( [TYPE, "TYPE"], typeBase, starsBase, r ); }
	;
	
integralType
	:	(	SBYTE
		|	BYTE
		|	SHORT
		|	USHORT
		|	INT
		|	UINT
		|	LONG
		|	ULONG
		|	CHAR
		)
		{ ## = #( [TYPE, "TYPE"], ##, [STARS, "STARS"], [ARRAY_RANKS, "ARRAY_RANKS"] ); }
	;
	
classType
	:	(	qualifiedIdentifier		// typeName
		|	OBJECT
		|	STRING
		)
		{ ## = #( [TYPE, "TYPE"], ##, [STARS, "STARS"], [ARRAY_RANKS, "ARRAY_RANKS"] ); }
	;

/*	
//
// A.2.4 Expressions
//
*/
argumentList
	:	argument ( COMMA! argument )*
		{ ## = #( [ARG_LIST, "ARG_LIST"], #argumentList ); }
	;
	
argument
	:	expression
	|	REF^ expression
	|	OUT^ expression
	;

constantExpression
	:	expression
	;
	
booleanExpression
	:	expression
	;
	
expressionList
	:	expression ( COMMA! expression )*
		{ ## = #( [EXPR_LIST, "EXPR_LIST"], #expressionList ); }
	;


/*	
//======================================
// 14.2.1 Operator precedence and associativity
//
// The following table summarizes all operators in order of precedence from lowest to highest:
//
// PRECEDENCE     SECTION  CATEGORY                     OPERATORS
//  lowest  (14)  14.13    Assignment                   = *= /= %= += -= <<= >>= &= ^= |=
//          (13)  14.12    Conditional                  ?:
//          (12)  14.11    Conditional OR               ||
//          (11)  14.11    Conditional AND              &&
//          (10)  14.10    Logical OR                   |
//          ( 9)  14.10    Logical XOR                  ^
//          ( 8)  14.10    Logical AND                  &
//          ( 7)  14.9     Equality                     == !=
//          ( 6)  14.9     Relational and type-testing  < > <= >= is as
//          ( 5)  14.8     Shift                        << >>
//          ( 4)  14.7     Additive                     +{binary} -{binary}
//          ( 3)  14.7     Multiplicative               * / %
//          ( 2)  14.6     Unary                        +{unary} -{unary} ! ~ ++x --x (T)x
//  highest ( 1)  14.5     Primary                      x.y f(x) a[x] x++ x-- new
//                                                      typeof checked unchecked
//
// NOTE: In accordance with lessons gleaned from the "java.g" file supplied with ANTLR, 
//       I have applied the following pattern to the rules for expressions:
// 
//           thisLevelExpression :
//               nextHigherPrecedenceExpression (OPERATOR nextHigherPrecedenceExpression)*
//
//       which is a standard recursive definition for a parsing an expression.
//
*/
expression
	:	assignmentExpression
		{ #expression = #( #[EXPR,"EXPR"], #expression ); }
	;

assignmentExpression
	:	conditionalExpression 
		(	(	ASSIGN^
			|	PLUS_ASSIGN^
			|	MINUS_ASSIGN^
			|	STAR_ASSIGN^
			|	DIV_ASSIGN^
			|	MOD_ASSIGN^
			|	BIN_AND_ASSIGN^
			|	BIN_OR_ASSIGN^
			|	BIN_XOR_ASSIGN^
			|	SHIFTL_ASSIGN^
			|	SHIFTR_ASSIGN^
			) 
			assignmentExpression 
		)?		
	;
	
conditionalExpression
	:	conditionalOrExpression ( QUESTION^ assignmentExpression
	                              COLON!    conditionalExpression
	                            )?	
	;
	
conditionalOrExpression
	:	conditionalAndExpression (	LOG_OR^ conditionalAndExpression )*
	
	;

conditionalAndExpression
	:	inclusiveOrExpression (	LOG_AND^ inclusiveOrExpression )*
	
	;
	
inclusiveOrExpression
	:	exclusiveOrExpression ( BIN_OR^ exclusiveOrExpression )*
		
	;
	
exclusiveOrExpression
	:	andExpression ( BIN_XOR^ andExpression )*
	;
	
andExpression
	:	equalityExpression (	BIN_AND^ equalityExpression )*
	;
	
equalityExpression
	:	relationalExpression ( ( EQUAL^ | NOT_EQUAL^ ) relationalExpression )*
	;
	
relationalExpression
	:	shiftExpression 
		(	( ( LTHAN^ | GTHAN^ | LTE^ | GTE^ ) shiftExpression )*
		|	( IS^ | AS^ ) type
		)
	;
	
shiftExpression
	:	additiveExpression (	( SHIFTL^ | SHIFTR^ ) additiveExpression )*
	;
	
additiveExpression
	:	multiplicativeExpression (	( PLUS^ | MINUS^ ) multiplicativeExpression )*
	;	

multiplicativeExpression
	:	unaryExpression ( ( STAR^ | DIV^ | MOD^ ) unaryExpression )*
	;
	
unaryExpression
	:	// castExpression
		//
		( OPEN_PAREN type CLOSE_PAREN unaryExpression )=> 
		o:OPEN_PAREN^ { #o.setType(CAST_EXPR); } type CLOSE_PAREN! unaryExpression
	|	// preIncrementExpression
		//
		INC^ unaryExpression
	|	// preDecrementExpression
		//
		DEC^ unaryExpression
	|	p:PLUS^  { #p.setType(UNARY_PLUS );  } unaryExpression
	|	m:MINUS^ { #m.setType(UNARY_MINUS ); } unaryExpression
	|	LOG_NOT^ unaryExpression
	|	BIN_NOT^ unaryExpression
	|	// pointerIndirectionExpression
		//
		s:STAR^ { #s.setType(PTR_INDIRECTION_EXPR); } unaryExpression
	|	// addressofExpression
		//
		b:BIN_AND^ { #b.setType(ADDRESS_OF_EXPR); } unaryExpression
	|	primaryExpression
	;
	
basicPrimaryExpression
		// primaryNoArrayCreationExpression		
		//
	:	(	literal
		|	identifier											// simpleName
		|	// parenthesizedExpression
			//
			o:OPEN_PAREN^ { #o.setType(PAREN_EXPR); } assignmentExpression CLOSE_PAREN!
		|	THIS^												// thisAccess
		|	BASE^
			(	DOT! identifier									// baseAccess
			|	OPEN_BRACK! expressionList CLOSE_BRACK!			// baseAccess
			)			
		|	newExpression
		|!	to_t:TYPEOF^ OPEN_PAREN!
			(	{ ((LA(1) == VOID) && (LA(2) == CLOSE_PAREN)) }? to_v:voidAsType CLOSE_PAREN!	// typeofExpression
				{ ## = #( #to_t, #to_v ); }
			|	to_typ:type CLOSE_PAREN!						// typeofExpression
				{ ## = #( #to_t, #to_typ ); }
			)
		|	SIZEOF^    OPEN_PAREN! qualifiedIdentifier CLOSE_PAREN!	// sizeofExpression
		|	CHECKED^   OPEN_PAREN! expression          CLOSE_PAREN!	// checkedExpression
		|	UNCHECKED^ OPEN_PAREN! expression          CLOSE_PAREN!	// uncheckedExpression
		|!	//--													// memberAccess
			ma_typ:predefinedType dt:DOT ma_id:identifier
			{
				#dt.setType(MEMBER_ACCESS_EXPR);
				## = #( #dt, #ma_typ, #ma_id );
			}
		)
	;

primaryExpression!
	:	bexpr:basicPrimaryExpression		{ ## = #bexpr; }
		(	options { greedy = true; } : 
			(	// invocationExpression  ::= primaryExpression OPEN_PAREN ( argumentList )? CLOSE_PAREN
				//
				op:OPEN_PAREN { #a = null; } ( a:argumentList )? CLOSE_PAREN!
				{
					#op.setType(INVOCATION_EXPR);
					## = #( #op, #bexpr, #a );
				}
			|	//	elementAccess		 ::= primaryNoArrayCreationExpression OPEN_BRACK expressionList CLOSE_BRACK
				//	pointerElementAccess ::= primaryNoArrayCreationExpression OPEN_BRACK expression     CLOSE_BRACK
				//
				ob:OPEN_BRACK elist:expressionList CLOSE_BRACK!
				{
					#ob.setType(ELEMENT_ACCESS_EXPR);
					## = #( #ob, #bexpr, #elist );
				}
			|	//	memberAccess		 ::= primaryExpression DOT identifier
				//
				dt:DOT ma_id:identifier
				{
					#dt.setType(MEMBER_ACCESS_EXPR);
					## = #( #dt, #bexpr, #ma_id );
				}
			|	ic:INC 															// postIncrementExpression
				{
					#ic.setType(POST_INC_EXPR);
					## = #( #ic, #bexpr );
				}
			|	dc:DEC															// postDecrementExpression
				{ 
					#dc.setType(POST_DEC_EXPR); 
					## = #( #dc, #bexpr );
				}
			|	pm_deref:DEREF pm_id:identifier									// pointerMemberAccess
				{ ## = #( #pm_deref, #bexpr, #pm_id ); }
			)
			{ #bexpr = ##; }
		)*															
	;

newExpression!
	:	n:NEW typ:type
		(	// objectCreationExpression	  ::= NEW type         OPEN_PAREN ( argumentList )? CLOSE_PAREN
			// delegateCreationExpression ::= NEW delegateType OPEN_PAREN expression        CLOSE_PAREN
			// NOTE: Will ALSO match 'delegateCreationExpression'
			//
			OPEN_PAREN! ( arglist:argumentList )? CLOSE_PAREN!
			{
				#n.setType(OBJ_CREATE_EXPR);
				## = #( #n, #typ, #arglist ); 
			}
		|	// arrayCreationExpression	::= NEW arrayType arrayInitializer
			//
			ar_init:arrayInitializer
			{
				#n.setType(ARRAY_CREATE_EXPR);
				## = #( #n, #typ, #ar_init ); 
			}
		|	// arrayCreationExpression 	::= NEW nonArrayType OPEN_BRACK expressionList CLOSE_BRACK ( rankSpecifiers )? ( arrayInitializer )?
			//
			OPEN_BRACK! elist:expressionList CLOSE_BRACK! 
			ar_spec2:rankSpecifiers
			( ar_init2:arrayInitializer )?
			{
				#n.setType(ARRAY_CREATE_EXPR);
				## = #( #n, #typ, #elist, #ar_spec2, #ar_init2 ); 
			}
		)
	;

literal
	:	TRUE							// BOOLEAN_LITERAL
	|	FALSE							// BOOLEAN_LITERAL
	|	INT_LITERAL
	|	UINT_LITERAL
	|	LONG_LITERAL
	|	ULONG_LITERAL
	|	DECIMAL_LITERAL
	|	FLOAT_LITERAL
	|	DOUBLE_LITERAL
	|	CHAR_LITERAL
	|	STRING_LITERAL
	|	NULL							// NULL_LITERAL
	;

predefinedType
	:	(	BOOL 
		|	BYTE
		|	CHAR
		|	DECIMAL
		|	DOUBLE
		|	FLOAT
		|	INT
		|	LONG
		|	OBJECT
		|	SBYTE
		|	SHORT
		|	STRING
		|	UINT
		|	ULONG
		|	USHORT
		)
		{ ## = #( [TYPE, "TYPE"], ##, [STARS, "STARS"], [ARRAY_RANKS, "ARRAY_RANKS"] ); }
	;
	
predefinedTypeName
	:	BOOL 
	|	BYTE
	|	CHAR
	|	DECIMAL
	|	DOUBLE
	|	FLOAT
	|	INT
	|	LONG
	|	OBJECT
	|	SBYTE
	|	SHORT
	|	STRING
	|	UINT
	|	ULONG
	|	USHORT
	;
	

/*
//
// A.2.5 Statements
//
*/
statement
	:	{ (IdentifierRuleIsPredictedByLA(1) && (LA(2) == COLON)) }? labeledStatement
	|	{ ((LA(1) == CONST) && TypeRuleIsPredictedByLA(2) && IdentifierRuleIsPredictedByLA(3)) ||
		  (TypeRuleIsPredictedByLA(1) && IdentifierRuleIsPredictedByLA(2)) }? declarationStatement
	|	( ( CONST )? type identifier )=> declarationStatement
	|	embeddedStatement
	|	preprocessorDirective[CodeMaskEnums.Statements]
	;
	
embeddedStatement
	:	block
	|	//emptyStatement
		//	
		s:SEMI { #s.setType(EMPTY_STMT); }
	|	expressionStatement
	|	selectionStatement
	|	iterationStatement
	|	jumpStatement
	|	tryStatement
	|	checkedStatement
	|	uncheckedStatement
	|	lockStatement
	|	usingStatement
	|	unsafeStatement
	|	fixedStatement
	;

	
body
	:	block	
	|	s:SEMI { #s.setType(EMPTY_STMT); }
	;

block
	:	o:OPEN_CURLY^ { #o.setType(BLOCK); } ( statement )* CLOSE_CURLY
	;
	
statementList
	:	(	statement )+
		{ #statementList = #( [STMT_LIST, "STMT_LIST"], #statementList ); }
	;
	
labeledStatement
	:	id:identifier c:COLON^ { #c.setType(LABEL_STMT); } stmt:statement
	;
	
declarationStatement
	:	localVariableDeclaration SEMI!
	|	localConstantDeclaration SEMI!
	;
	
localVariableDeclaration
	:	type localVariableDeclarators
		{
			## = #( [LOCVAR_DECLS, "LOCVAR_DECLS"], ## ); 
		}
	;
	
localVariableDeclarators
	:	localVariableDeclarator
		( 
			COMMA! localVariableDeclarator
		)*
	;
	
localVariableDeclarator
	:	identifier ( ASSIGN! localVariableInitializer )?
		{
			## = #( [VAR_DECLARATOR, "VAR_DECLARATOR"], ## ); 
		}
	;
	
localVariableInitializer
	:	(	expression
		|	arrayInitializer
		)
		{ #localVariableInitializer = #( [LOCVAR_INIT, "LOCVAR_INIT"], #localVariableInitializer ); }
	;
	
localConstantDeclaration
	:	c:CONST^ { #c.setType(LOCAL_CONST); } type constantDeclarators
	;
	
constantDeclarators
	:	constantDeclarator
		(
			COMMA! constantDeclarator
		)*
	;
	
constantDeclarator
	:	identifier a:ASSIGN^ { #a.setType(CONST_DECLARATOR); } constantExpression
	;
	
expressionStatement
	:	statementExpression s:SEMI^
		{ #s.setType(EXPR_STMT); }
	;
	
statementExpression!
	:	aexpr:assignmentExpression
		{ ## = #aexpr; }
/*
	:	invocationExpression
	|	objectCreationExpression
	|	assignmentExpression
	|	postIncrementExpression
	|	postDecrementExpression
	|	preIncrementExpression
	|	preDecrementExpression
*/
	;
	
selectionStatement
	:	ifStatement
	|	switchStatement
	;
	
ifStatement
	:	IF^ OPEN_PAREN! booleanExpression CLOSE_PAREN! embeddedStatement 
		( options { greedy = true; } : elseStatement )?
	;
	
elseStatement
	:	ELSE^ embeddedStatement
	;
	
switchStatement
	:	SWITCH^ OPEN_PAREN! expression CLOSE_PAREN! switchBlock
	;
	
switchBlock
	:	OPEN_CURLY^ ( switchSections )? CLOSE_CURLY
	;
	
switchSections
	:	( switchSection )+
	;
	
switchSection!
	:	lbl:switchLabels stmt:statementList
		{ ## = #( [SWITCH_SECTION, "SWITCH_SECTION"], #lbl, #stmt ); }
	;
	
switchLabels
	:	( switchLabel )+
		{ #switchLabels = #( [SWITCH_LABELS, "SWITCH_LABELS"], #switchLabels ); }
	;
	
switchLabel
	:	CASE^ constantExpression COLON!
	|	DEFAULT^ COLON!
	;
	
iterationStatement
	:	whileStatement
	|	doStatement
	|	forStatement
	|	foreachStatement
	;
	
whileStatement
	:	WHILE^ OPEN_PAREN! booleanExpression CLOSE_PAREN! embeddedStatement
	;
	
doStatement
	:	DO^ embeddedStatement WHILE! OPEN_PAREN! booleanExpression CLOSE_PAREN! SEMI!
	;
	
forStatement
	:	FOR^ OPEN_PAREN! forInitializer SEMI! forCondition SEMI! forIterator CLOSE_PAREN! embeddedStatement
	;
	
forInitializer
	:	(	{ (TypeRuleIsPredictedByLA(1) && IdentifierRuleIsPredictedByLA(2)) }? localVariableDeclaration
		|	( type identifier )=> localVariableDeclaration
		|	statementExpressionList
		)?
		{ #forInitializer = #( [FOR_INIT, "FOR_INIT"], #forInitializer ); }
	;
	
forCondition
	:	(	booleanExpression
		)?
		{ #forCondition = #( [FOR_COND, "FOR_COND"], #forCondition ); }
	;
	
forIterator
	:	(	statementExpressionList
		)?
		{ #forIterator = #( [FOR_ITER, "FOR_ITER"], #forIterator ); }
	;
	
statementExpressionList
	:	statementExpression ( COMMA! statementExpression )*
	;
	
foreachStatement!
	:	f:FOREACH OPEN_PAREN! t:type id:identifier IN! e:expression CLOSE_PAREN! s:embeddedStatement
		{ ## = #( #f, #( [LOCVAR_DECLS], #t, #( [VAR_DECLARATOR], #id ) ), #e, #s ); }
	;
	
jumpStatement
	:	breakStatement
	|	continueStatement
	|	gotoStatement
	|	returnStatement
	|	throwStatement
	;
	
breakStatement
	:	BREAK^ SEMI!
	;
	
continueStatement
	:	CONTINUE^ SEMI!
	;
	
gotoStatement
	:	GOTO^ 
		(	identifier SEMI!
		|	CASE constantExpression SEMI!
		|	DEFAULT SEMI!
		)
	;
	
returnStatement
	:	RETURN^ ( expression )? SEMI!
	;
	
throwStatement
	:	THROW^ ( expression )? SEMI!
	;
	
tryStatement
	:	TRY^ block 
		(	finallyClause
		|	catchClauses ( finallyClause )?
		)
	;
	
catchClauses
	:	( options { greedy = true; } : specificCatchClause )+ ( generalCatchClause )?
	|	generalCatchClause
	;
	
specificCatchClause!
	:	c:CATCH^ OPEN_PAREN! ctype:classType ( id:identifier )? CLOSE_PAREN! b:block
		{
			if (#id == null)
				## = #( #c, #b, #ctype );
			else
				## = #( #c, #b, #( [LOCVAR_DECLS], #ctype, #( [VAR_DECLARATOR], #id ) ) );
		}
	;
	
generalCatchClause
	:	CATCH^ block
	;
	
finallyClause
	:	FINALLY^ block
	;
	
checkedStatement
	:	CHECKED^ block
	;
	
uncheckedStatement
	:	UNCHECKED^ block
	;
	
lockStatement
	:	LOCK^ OPEN_PAREN! expression CLOSE_PAREN! embeddedStatement
	;
	
usingStatement
	:	USING^ OPEN_PAREN! resourceAcquisition CLOSE_PAREN! embeddedStatement
	;
	
unsafeStatement
	:	UNSAFE^ block
	;

resourceAcquisition
	:	{ (TypeRuleIsPredictedByLA(1) && IdentifierRuleIsPredictedByLA(2)) }? localVariableDeclaration
	|	( type identifier )=> localVariableDeclaration
	|	expression
	;
	
compilationUnit
	:	justPreprocessorDirectives
		usingDirectives
		globalAttributes
		namespaceMemberDeclarations
	    EOF!
	    {
			## = #( [COMPILATION_UNIT, "COMPILATION_UNIT"], ## ); 
		}
	;
	
usingDirectives
	:	(	options { greedy = true; } 
		:	{ !PPDirectiveIsPredictedByLA(1) }? usingDirective 
		|	( preprocessorDirective[CodeMaskEnums.UsingDirectives] )=> 
			preprocessorDirective[CodeMaskEnums.UsingDirectives]
		)*
		{	
			#usingDirectives = #( [USING_DIRECTIVES, "USING_DIRECTIVES"], ## ); 
		}
	;
	
usingDirective
	:	u:USING^
		(	// UsingAliasDirective
			{ (IdentifierRuleIsPredictedByLA(1) && (LA(2) == ASSIGN)) }? identifier ASSIGN! qualifiedIdentifier SEMI!
			{	
				#u.setType(USING_ALIAS_DIRECTIVE);
			}
		|	// UsingNamespaceDirective
			qualifiedIdentifier SEMI!
			{	
				#u.setType(USING_NAMESPACE_DIRECTIVE);
			}
		)
	;
		
namespaceMemberDeclarations
	:	(	options { greedy = true; } 
		:	{ PPDirectiveIsPredictedByLA(1) }? preprocessorDirective[CodeMaskEnums.NamespaceMemberDeclarations]
		|	namespaceMemberDeclaration 
		)*
	;
	
namespaceMemberDeclaration
	:	namespaceDeclaration
	|	a:attributes! m:modifiers! typeDeclaration[#a, #m]
	;
	
typeDeclaration [AST attribs, AST modifiers]
	:	classDeclaration[attribs, modifiers]
	|	structDeclaration[attribs, modifiers]
	|	interfaceDeclaration[attribs, modifiers]
	|	enumDeclaration[attribs, modifiers]
	|	delegateDeclaration[attribs, modifiers]
	;

namespaceDeclaration
	:	NAMESPACE^ qualifiedIdentifier namespaceBody ( options { greedy = true; } : SEMI! )?
	;
	
namespaceBody
	:	o:OPEN_CURLY^ { #o.setType(NAMESPACE_BODY); }
			usingDirectives 
			namespaceMemberDeclarations 
		CLOSE_CURLY
	;
	
modifiers
	:	( modifier )*
		{ #modifiers = #( [MODIFIERS, "MODIFIERS"], #modifiers ); }
	;

modifier
	:	(	ABSTRACT
		|	NEW
		|	OVERRIDE
		|	PUBLIC
		|	PROTECTED
		|	INTERNAL
		|	PRIVATE
		|	SEALED
		|	STATIC
		|	VIRTUAL
		|	EXTERN
		|	READONLY
		|	UNSAFE
		|	VOLATILE
		)
	;


//	
// A.2.6 Classes
//

classDeclaration! [AST attribs, AST modifiers]
	:	cl:CLASS id:identifier ba:classBase bo:classBody ( options { greedy = true; } : SEMI! )?
		{ ## = #( #cl, #attribs, #modifiers, #id, #ba, #bo ); }
	;
	
classBase
	:	(	COLON! type ( COMMA! type )*
		)?
		{ #classBase = #( [CLASS_BASE, "CLASS_BASE"], #classBase ); }
	;
	
classBody
	:	o:OPEN_CURLY^ { #o.setType(TYPE_BODY); } classMemberDeclarations CLOSE_CURLY
	;
	
classMemberDeclarations		
	:	(	options { greedy = true; } 
		:	{ PPDirectiveIsPredictedByLA(1) }? preprocessorDirective[CodeMaskEnums.ClassMemberDeclarations]
		|	classMemberDeclaration 
		)*
		{ ## = #( [MEMBER_LIST, "MEMBER_LIST"], ## ); }
	;
	
classMemberDeclaration
	:	a:attributes! m:modifiers!
		(	destructorDeclaration[#a, #m]
		|	typeMemberDeclaration[#a, #m]
		)
	;
	
typeMemberDeclaration [AST attribs, AST modifiers]
{
	bool 	IsBinaryOp = false;
	AST 	OpParams = null;
}
	:!	// constantDeclaration
		c:CONST t:type cdecl:constantDeclarators SEMI!
		{ ## = #( #c, #attribs, #modifiers, #t, #cdecl ); }
		
	|!	// eventDeclaration
		ev:EVENT ev_typ:type 
		(	{ IdentifierRuleIsPredictedByLA(1) && (LA(2)==ASSIGN || LA(2)==SEMI ||LA(2)==COMMA) }?
			ev_v:variableDeclarators SEMI!
			{ ## = #( #ev, #attribs, #modifiers, #ev_typ, #ev_v ); }
		|	ev_id:qualifiedIdentifier OPEN_CURLY! ev_e:eventAccessorDeclarations ev_c:CLOSE_CURLY
			{ ## = #( #ev, #attribs, #modifiers, #ev_typ, #ev_id, #ev_e, #ev_c ); }
		)
		
	|!	// constructorDeclaration
		cd_id:identifier OPEN_PAREN! ( cd_fp:formalParameterList )? CLOSE_PAREN! 
		( cd_ci:constructorInitializer )? cd_cb:constructorBody
		{
			if ( ((ASTNode) modifiers).GetFirstChildOfType(STATIC) == null )
			{
				## = #( [CTOR_DECL, "CTOR_DECL"], #attribs, #modifiers, #cd_id, #cd_cb, #cd_fp, #cd_ci ); 
				##.CopyPositionFrom( #cd_id );
			}
			else
			{
				## = #( [STATIC_CTOR_DECL, "STATIC_CTOR_DECL"], #attribs, #modifiers, #cd_id, #cd_cb ); 
				##.CopyPositionFrom( #cd_id );
			}
		}

	|!	// methodDeclaration
		{ ((LA(1) == VOID) && (LA(2) != STAR)) }? 
		mdv_rt:voidAsType mdv_mn:qualifiedIdentifier mdv_opn:OPEN_PAREN! ( mdv_fp:formalParameterList )? CLOSE_PAREN! 
		mdv_mb:methodBody
		{
			## = #( [METHOD_DECL, "METHOD_DECL"], #attribs, #modifiers, #mdv_rt, #mdv_mn, #mdv_mb, #mdv_fp ); 
		  	##.CopyPositionFrom( #mdv_mn );
		}
		
	|!	typ1:type
		(	// unaryOperatorDeclarator or binaryOperatorDeclarator
			OPERATOR! od_op:overloadableOperator OPEN_PAREN! 	
				od_f1:fixedOperatorParameter 
				(	COMMA! od_f2:fixedOperatorParameter 
					{ IsBinaryOp = true; } 
				)?
				{ OpParams = #( [FORMAL_PARAMETER_LIST, "FORMAL_PARAMETER_LIST"], #od_f1, #od_f2 ); }
			CLOSE_PAREN!
			{
				if (!IsBinaryOp)
				{
					if (#od_op.Type == PLUS) 
						#od_op.Type = UNARY_PLUS;
					else if (#od_op.Type == MINUS)
						#od_op.Type = UNARY_MINUS;
						
					## = #( [UNARY_OP_DECL, "UNARY_OP_DECL"], #attribs, #modifiers, #typ1, #od_op, OpParams );
				}
				else
				{
					## = #( [BINARY_OP_DECL, "BINARY_OP_DECL"], #attribs, #modifiers, #typ1, #od_op, OpParams );
				}
				##.CopyPositionFrom( #od_op );
			}
			od_body:operatorBody
			{ ##.addChildEx(#od_body); }
		|
			// fieldDeclaration
			{ IdentifierRuleIsPredictedByLA(1) && (LA(2)==ASSIGN || LA(2)==SEMI ||LA(2)==COMMA) }?
			fd_v:variableDeclarators SEMI!
			{ ## = #( [FIELD_DECL, "FIELD_DECL"], #attribs, #modifiers, #typ1, #fd_v ); }
		|	qid1:qualifiedIdentifier
		
			(	// propertyDeclaration
				OPEN_CURLY!
					pd_a:accessorDeclarations 
				pd_c:CLOSE_CURLY
				{
					## = #( [PROPERTY_DECL, "PROPERTY_DECL"], #attribs, #modifiers, #typ1, #qid1, #pd_a, #pd_c );
					##.CopyPositionFrom( #qid1 );
				}
				
			|	// methodDeclaration
				OPEN_PAREN! ( md_fp:formalParameterList )? CLOSE_PAREN! 
				md_mb:methodBody
				{
					## = #( [METHOD_DECL, "METHOD_DECL"], #attribs, #modifiers, #typ1, #qid1, #md_mb, #md_fp ); 
				  	##.CopyPositionFrom( #qid1 );
				}
				
			|	// indexerDeclaration
				DOT! ixq_t:THIS OPEN_BRACK! ixq_fp:formalParameterList CLOSE_BRACK!
				OPEN_CURLY! ixq_adecls:accessorDeclarations ixq_c:CLOSE_CURLY
				{
					## = #( [INDEXER_DECL, "INDEXER_DECL"], #attribs, #modifiers, #typ1, #qid1, #ixq_t, #ixq_fp, #ixq_adecls, #ixq_c );
					##.CopyPositionFrom( #ixq_t );
				}
			)
			
		|	// indexerDeclaration
			ix_t:THIS OPEN_BRACK! ix_fp:formalParameterList CLOSE_BRACK!
			OPEN_CURLY! ix_adecls:accessorDeclarations ix_c:CLOSE_CURLY
			{
				## = #( [INDEXER_DECL, "INDEXER_DECL"], #attribs, #modifiers, #typ1, #qid1, #ix_t, #ix_fp, #ix_adecls, #ix_c );
				##.CopyPositionFrom( #ix_t );
			}
		)
	
	|!	imp:IMPLICIT OPERATOR! imp_typ1:type OPEN_PAREN! imp_params:oneOperatorParameter CLOSE_PAREN!		// conversionOperatorDeclarator
		{
			## = #( [CONV_OP_DECL, "CONV_OP_DECL"], #attribs, #modifiers, #imp, #imp_typ1, #imp_params );
			##.CopyPositionFrom( #imp );
		}
		imp_body:operatorBody
		{ ##.addChildEx(#imp_body); }

	|!	exp:EXPLICIT OPERATOR! exp_typ1:type OPEN_PAREN! exp_params:oneOperatorParameter CLOSE_PAREN!		// conversionOperatorDeclarator
		{
			## = #( [CONV_OP_DECL, "CONV_OP_DECL"], #attribs, #modifiers, #exp, #exp_typ1, #exp_params );
			##.CopyPositionFrom( #exp );
		}
		exp_body:operatorBody
		{ ##.addChildEx(#exp_body); }

	|	typeDeclaration[attribs, modifiers]
	;
	
variableDeclarators
	:	variableDeclarator
		( 
			COMMA! variableDeclarator
		)*
	;
	
variableDeclarator
	:	identifier ( ASSIGN! variableInitializer )?
		{
			## = #( [VAR_DECLARATOR, "VAR_DECLARATOR"], ## ); 
		}
	;
	
variableInitializer
	:	(	expression
		|	arrayInitializer
		|	stackallocInitializer
		)
		{ #variableInitializer = #( [VAR_INIT, "VAR_INIT"], #variableInitializer ); }
	;
		
returnType
	:	{ ((LA(1) == VOID) && (LA(2) != STAR)) }? voidAsType
	|	type
	;
	
methodBody
	:	b:body
	;
	
formalParameterList
	:	fa:attributes!
		(	fixedParameters[#fa] ( COMMA! pa:attributes! parameterArray[#pa] )?
		|	parameterArray[#fa]
		)
		{ ## = #( [FORMAL_PARAMETER_LIST, "FORMAL_PARAMETER_LIST"], ## ); }
	;
	
fixedParameters [AST attribs]
	:	fixedParameter[attribs] ( options { greedy = true; } : COMMA! a:attributes! fixedParameter[#a] )*
	;
	
fixedParameter! [AST attribs]
	:	( mod:parameterModifier )? typ:type id:identifier
		{
			## = #( [PARAMETER_FIXED, "PARAMETER_FIXED"], #attribs, #typ, #id, #mod ); 
		  	##.CopyPositionFrom( #id );
		}
	;
	
parameterModifier
	:	REF
	|	OUT
	;
	
parameterArray! [AST attribs]
//	:	PARAMS! arrayType identifier
	:	p:PARAMS t:type id:identifier
		{ ## = #( #p, #attribs, #t, #id ); }
	;
	
accessorDeclarations!
	:	a1:attributes
		(	g1:getAccessorDeclaration[#a1] 						{ ## = #g1; }
			( a2:attributes s1:setAccessorDeclaration[#a2]		{ #g1.setNextSibling(#s1); 
			 													  #s1.setPreviousSibling(#g1); } 
			)?
		|	s2:setAccessorDeclaration[#a1] 					  	{ ## = #s2; }
			( a3:attributes g2:getAccessorDeclaration[#a3] 		{ #s2.setNextSibling(#g2); 
																  #g2.setPreviousSibling(#s2); }
			)?
		)
	;
	
getAccessorDeclaration! [AST attribs]
	:	g:"get" abody:accessorBody
		{ ## = #( #g, #attribs, #abody ); }
	;
	
setAccessorDeclaration! [AST attribs]
	:	s:"set" abody:accessorBody
		{ ## = #( #s, #attribs, #abody ); }
	;
	
accessorBody
	:	body
	;
	
eventAccessorDeclarations!
	:	a1:attributes
		(	add1:addAccessorDeclaration[#a1]    a2:attributes rem1:removeAccessorDeclaration[#a2]
			{
				## = #add1;
			  	#add1.setNextSibling(#rem1); 
			  	#rem1.setPreviousSibling(#add1); 
			}
		|	rem2:removeAccessorDeclaration[#a1] a3:attributes add2:addAccessorDeclaration[#a3]
			{
				## = #add2;
			  	#add2.setNextSibling(#rem2);
			  	#rem2.setPreviousSibling(#add2); 
			}
		)
	;
	
addAccessorDeclaration! [AST attribs]
	:	a:"add" b:block
		{ ## = #( #a, #attribs, #b ); }
	;
	
removeAccessorDeclaration! [AST attribs]
	:	r:"remove" b:block
		{ ## = #( #r, #attribs, #b ); }
	;

overloadableOperator
		// Unary-or-Binary Operators
		//
	:	PLUS
	|	MINUS
	
		// Unary-only Operators
		//
	|	LOG_NOT
	|	BIN_NOT
	|	INC
	|	DEC
	|	TRUE		//"true"
	|	FALSE		//"false"

		// Binary-only Operators
		//
	|	STAR 
	|	DIV 
	|	MOD 
	|	BIN_AND 
	|	BIN_OR 
	|	BIN_XOR 
	|	SHIFTL 
	|	SHIFTR 
	|	EQUAL 
	|	NOT_EQUAL 
	|	GTHAN
	|	LTHAN 
	|	GTE 
	|	LTE 
	;
	
oneOperatorParameter
	:	fixedOperatorParameter
		{ ## = #( [FORMAL_PARAMETER_LIST, "FORMAL_PARAMETER_LIST"], ## ); }
	;
	
fixedOperatorParameter!
	:	typ:type id:identifier
		{
			## = #( [PARAMETER_FIXED, "PARAMETER_FIXED"], [ATTRIBUTE_SECTIONS, "ATTRIBUTE_SECTIONS"], #typ, #id ); 
			##.CopyPositionFrom( #id );
		}
	;
	
operatorBody
	:	b:body
	;

constructorInitializer
	:	c:COLON!
		(	BASE^ OPEN_PAREN! ( argumentList )? CLOSE_PAREN!
		|	THIS^ OPEN_PAREN! ( argumentList )? CLOSE_PAREN!
		)
	;
	
constructorBody
	:	b:body
	;

destructorDeclaration! [AST attribs, AST modifiers]
	:	b:BIN_NOT! id:identifier OPEN_PAREN! CLOSE_PAREN! dbody:destructorBody
		{
			## = #( [DTOR_DECL, "DTOR_DECL"], #attribs, #modifiers, #id, #dbody ); 
			##.CopyPositionFrom( #id );
		}
	;
	
destructorBody
	:	b:body
	;

	
//
// A.2.7 Structs
//

structDeclaration! [AST attribs, AST modifiers]
	:	st:STRUCT^ id:identifier si:structInterfaces sb:structBody ( options { greedy = true; } : SEMI! )?
		{ ## = #( #st, #attribs, #modifiers, #id, #si, #sb ); }
	;
	
structInterfaces
	:	( COLON! type ( COMMA! type )* )?
		{ ## = #( [STRUCT_BASE, "STRUCT_BASE"], #structInterfaces ); }
	;
	
structBody
	:	o:OPEN_CURLY^ { #o.setType(TYPE_BODY); } structMemberDeclarations CLOSE_CURLY
;
	
structMemberDeclarations
	:	(	options { greedy = true; } 
		:	{ PPDirectiveIsPredictedByLA(1) }? preprocessorDirective[CodeMaskEnums.StructMemberDeclarations]
		|	structMemberDeclaration
		)*
		{ ## = #( [MEMBER_LIST, "MEMBER_LIST"], ## ); }
	;
	
structMemberDeclaration
	:	a:attributes! m:modifiers! typeMemberDeclaration[#a, #m]
	;

	
//
// A.2.8 Arrays
//

nonArrayType
	:	type
	;
	
rankSpecifiers
	:	// CONFLICT:	ANTLR says this about this line:
		//						ECMA-CSharp.g:1295: warning: nondeterminism upon
		//						ECMA-CSharp.g:1295: 	k==1:OPEN_BRACK
		//						ECMA-CSharp.g:1295: 	k==2:COMMA,CLOSE_BRACK
		//						ECMA-CSharp.g:1295: 	between alt 1 and exit branch of block
		//						!FIXME! -- if possible, can't see the problem right now.
		(	options { greedy = true; } : rankSpecifier )*
		//( rankSpecifier )+
		{ #rankSpecifiers = #( [ARRAY_RANKS, "ARRAY_RANKS"], #rankSpecifiers ); }
	;
	
rankSpecifier
	:	o:OPEN_BRACK^ { #o.setType(ARRAY_RANK); } ( options { greedy = true; } : COMMA )* CLOSE_BRACK!
	;
	
arrayInitializer
	:	o:OPEN_CURLY^					{ #o.setType(ARRAY_INIT); }
		(	CLOSE_CURLY
		|	variableInitializerList (COMMA!)? CLOSE_CURLY
		)
	;
	
variableInitializerList
	:	variableInitializer ( options { greedy = true; } : COMMA! variableInitializer )*
		{ #variableInitializerList = #( [VAR_INIT_LIST, "VAR_INIT_LIST"], #variableInitializerList ); }
	;

	
// 
// A.2.9 Interfaces
//

interfaceDeclaration! [AST attribs, AST modifiers]
	:	iface:INTERFACE id:identifier ibase:interfaceBase ibody:interfaceBody ( options { greedy = true; } : SEMI! )?
		{ ## = #( #iface, #attribs, #modifiers, #id, #ibase, #ibody );  }
	;
	
interfaceBase
	:	( COLON! type ( COMMA! type )* )?
		{ ## = #( [INTERFACE_BASE, "INTERFACE_BASE"], #interfaceBase ); }
	;
	
interfaceBody
	:	o:OPEN_CURLY^ { #o.setType(TYPE_BODY); } interfaceMemberDeclarations CLOSE_CURLY
	;
	
interfaceMemberDeclarations
	:	(	options { greedy = true; } 
		:	{ PPDirectiveIsPredictedByLA(1) }? preprocessorDirective[CodeMaskEnums.InterfaceMemberDeclarations]
		|	interfaceMemberDeclaration
		)*
		{ ## = #( [MEMBER_LIST, "MEMBER_LIST"], ## ); }
	;
	
interfaceMemberDeclaration
{
	ASTNode modifiers = #[MODIFIERS, "MODIFIERS"];
}
	:	attribs:attributes! ( n:NEW! { modifiers.addChildEx(#n); } )? 	
		(!	// interfaceMethodDeclaration
			{ ((LA(1) == VOID) && (LA(2) != STAR)) }?
			im1_rt:voidAsType im1_id:identifier OPEN_PAREN! ( im1_fp:formalParameterList )? CLOSE_PAREN! 
			im1_s:SEMI { #im1_s.setType(EMPTY_STMT); }
			{
				## = #( [METHOD_DECL, "METHOD_DECL"], #attribs, #modifiers, #im1_rt, #im1_id, #im1_s, #im1_fp ); 
				##.CopyPositionFrom( #im1_id );
			}

		|!	typ1:type 
			(	// interfaceIndexerDeclaration
				ix_t:THIS OPEN_BRACK! ix_fp:formalParameterList CLOSE_BRACK! 
				OPEN_CURLY! ix_acc:interfaceAccessors ix_c:CLOSE_CURLY
				{
					## = #( [INDEXER_DECL, "INDEXER_DECL"], #attribs, #modifiers, #typ1, #ix_t, #ix_fp, #ix_acc, #ix_c ); 
					##.CopyPositionFrom( #ix_t );
				}
				
			|	id1:identifier
				(	// interfaceMethodDeclaration
					OPEN_PAREN! ( im2_fp:formalParameterList )? CLOSE_PAREN! im2_s:SEMI { #im2_s.setType(EMPTY_STMT); }
					{
						## = #( [METHOD_DECL, "METHOD_DECL"], #attribs, #modifiers, #typ1, #id1, #im2_s, #im2_fp ); 
						##.CopyPositionFrom( #id1 );
					}
					
				|	// interfacePropertyDeclaration
					OPEN_CURLY! ip_acc:interfaceAccessors ip_c:CLOSE_CURLY
					{
						## = #( [PROPERTY_DECL, "PROPERTY_DECL"], #attribs, #modifiers, #typ1, #id1, #ip_acc, #ip_c ); 
						##.CopyPositionFrom( #id1 );
					}
				)
			)
			
		|	// interfaceEventDeclaration
			ev:EVENT ev_typ:type ev_id:identifier SEMI!
			{ ## = #( #ev, #attribs, #modifiers, #ev_typ, #( [VAR_DECLARATOR, "VAR_DECLARATOR"], #ev_id ) ); }
		)
	;
	

interfaceAccessors!
	:	a1:attributes
		(	g1:getAccessorDeclaration[#a1] 						{ ## = #g1; }
			( a2:attributes s1:setAccessorDeclaration[#a2]		{ #g1.setNextSibling(#s1); 
																  #s1.setPreviousSibling(#g1); } 
			)?
		|	s2:setAccessorDeclaration[#a1] 					  	{ ## = #s2; }
			( a3:attributes g2:getAccessorDeclaration[#a3] 		{ #s2.setNextSibling(#g2);
																  #g2.setPreviousSibling(#s2); } 
			)?
		)
	;
	


//
//	A.2.10 Enums
//

enumDeclaration! [AST attribs, AST modifiers]
	:	en:ENUM id:identifier ebase:enumBase ebody:enumBody ( options { greedy = true; } : SEMI! )?
		{ ## = #( #en, #attribs, #modifiers, #id, #ebase, #ebody ); }
	;
	
enumBase!
	{
		bool empty = true; 
	}
	:	( c:COLON { #c.setType(ENUM_BASE); empty = false; } t:integralType )?
		{
			if (empty)
			{
				## = #[ENUM_BASE, "ENUM_BASE"]; 
			}
			else
			{
				## = #( #c, #t );
			}
		}
	;
	
enumBody
	:	o:OPEN_CURLY^ { #o.setType(TYPE_BODY); } ( enumMemberDeclarations ( COMMA! )? )? CLOSE_CURLY
	;
	
enumMemberDeclarations
	:	a1:attributes! enumMemberDeclaration[#a1] 
		(	options { greedy = true; } : 
			COMMA! a2:attributes! enumMemberDeclaration[#a2] 
		)*
		{ ## = #( [MEMBER_LIST, "MEMBER_LIST"], ## ); }
 	;
 	
enumMemberDeclaration! [AST attribs]
	:	id:identifier ( ASSIGN! cexpr:constantExpression )?
		{ ## = #( #id, #attribs, #cexpr ); }
 	;


//
// A.2.11 Delegates
//

delegateDeclaration! [AST attribs, AST modifiers]
	{ 
			AST typ = null; 
		}
	:	dlg:DELEGATE 
		( 	{ ((LA(1) == VOID) && IdentifierRuleIsPredictedByLA(2)) }? 
			typ1:voidAsType						{ typ = #typ1; }
		| 	typ2:type 							{ typ = #typ2; }
		) 
		id:identifier OPEN_PAREN! ( fp:formalParameterList )? CLOSE_PAREN! SEMI!
		{ ## = #( #dlg, #attribs, #modifiers, #typ, #id, #fp ); }
	;
	

//
// A.2.12 Attributes
//

globalAttributes
	:	(	options { greedy = true; } 
		:	{ !PPDirectiveIsPredictedByLA(1) }? globalAttributeSection
		|	( preprocessorDirective[CodeMaskEnums.GlobalAttributes] )=>
			preprocessorDirective[CodeMaskEnums.GlobalAttributes]
		)*
		{ #globalAttributes = #( [GLOBAL_ATTRIBUTE_SECTIONS, "GLOBAL_ATTRIBUTE_SECTIONS"], #globalAttributes ); }
	;
	
globalAttributeSection
	:	o:OPEN_BRACK^ { #o.setType(GLOBAL_ATTRIBUTE_SECTION); } 
			"assembly"! COLON! attributeList ( COMMA! )? 
		CLOSE_BRACK!
	;

attributes
	:	(	options { greedy = true; } 
		:	{ !PPDirectiveIsPredictedByLA(1) }? attributeSection 
		|	( preprocessorDirective[CodeMaskEnums.Attributes] )=>
			preprocessorDirective[CodeMaskEnums.Attributes]
		)*
		{ #attributes = #( [ATTRIBUTE_SECTIONS, "ATTRIBUTE_SECTIONS"], #attributes ); }
	;
	
attributeSection
	:	o:OPEN_BRACK^ { #o.setType(ATTRIBUTE_SECTION); } 
			( attributeTarget COLON! )? attributeList ( COMMA! )? 
		CLOSE_BRACK!
	;
	
attributeTarget
	:	"field"
	|	EVENT
	|	"method"
	|	"module"
	|	"param"
	|	"property"
	|	RETURN
	|	"type"
	;

attributeList
	:	attribute ( options { greedy = true; } : COMMA! attribute )*
	;
	
attribute
	:	( predefinedTypeName | qualifiedIdentifier ) ( attributeArguments )?
		{ #attribute = #( [ATTRIBUTE, "ATTRIBUTE"], #attribute ); }
	;
	
attributeArguments
	:	OPEN_PAREN!
		(	CLOSE_PAREN!
		|	{ (IdentifierRuleIsPredictedByLA(1) && (LA(2) == ASSIGN)) }? namedArgumentList CLOSE_PAREN!
		|	positionalArgumentList ( COMMA! namedArgumentList )? CLOSE_PAREN!
		)
	;
	
positionalArgumentList
	:	positionalArgument 
		(	// CONFLICT: ANTLR thinks this is ambiguous, because
			//           in rule 'attributeArguments' a COMMA also
			//				 separates positionalArgument & namedArgument. 
			//           !FIXME! if possible.
			options { greedy = true; }
			:	COMMA! positionalArgument 
		)*
		{ #positionalArgumentList = #( [POSITIONAL_ARGLIST, "POSITIONAL_ARGLIST"], #positionalArgumentList ); }
	;
	
positionalArgument
	:	attributeArgumentExpression
		{ #positionalArgument = #( [POSITIONAL_ARG, "POSITIONAL_ARG"], #positionalArgument ); }
	;
	
namedArgumentList
	:	namedArgument ( COMMA! namedArgument )*
		{ #namedArgumentList = #( [NAMED_ARGLIST, "NAMED_ARGLIST"], #namedArgumentList ); }
	;
	
namedArgument
	:	identifier ASSIGN! attributeArgumentExpression
		{ #namedArgument = #( [NAMED_ARG, "NAMED_ARG"], #namedArgument ); }
	;
	
attributeArgumentExpression
	:	expression
		{ #attributeArgumentExpression = #( [ATTRIB_ARGUMENT_EXPR, "ATTRIB_ARGUMENT_EXPR"], #attributeArgumentExpression ); }
	;

//
// A.3 Grammar extensions for unsafe code
// 

fixedStatement
//	:	FIXED^ OPEN_PAREN! pointerType fixedPointerDeclarators CLOSE_PAREN! embeddedStatement
	:	FIXED^ OPEN_PAREN! type        fixedPointerDeclarators CLOSE_PAREN! embeddedStatement
	;
	
fixedPointerDeclarators
	:	fixedPointerDeclarator ( COMMA! fixedPointerDeclarator )*
	;
	
fixedPointerDeclarator
	:	identifier ASSIGN! fixedPointerInitializer
		{ ## = #( [PTR_DECLARATOR, "PTR_DECLARATOR"], ## ); }
	;
	
fixedPointerInitializer
	:	expression
		{ ## = #( [PTR_INIT, "PTR_INIT"], ## ); }
	;	
	
stackallocInitializer
	:	STACKALLOC^ qualifiedIdentifier OPEN_BRACK! expression CLOSE_BRACK!
	;

//
// A.1.10 Pre-processing directives
// 

justPreprocessorDirectives
	:	(	options { greedy = true; } 
		:	{ SingleLinePPDirectiveIsPredictedByLA(1) }? singleLinePreprocessorDirective
		|	( preprocessorDirective[CodeMaskEnums.PreprocessorDirectivesOnly] )=> 
			preprocessorDirective[CodeMaskEnums.PreprocessorDirectivesOnly]
		)*
		{	
			## = #( [PP_DIRECTIVES, "PP_DIRECTIVES"], ## ); 
		}
	;
	
preprocessorDirective [CodeMaskEnums codeMask]
	:	PP_DEFINE^   PP_IDENT
	|	PP_UNDEFINE^ PP_IDENT
	|	lineDirective
	|	PP_ERROR^   ppMessage
	|	PP_WARNING^ ppMessage
	|	regionDirective[codeMask]
	|	conditionalDirective[codeMask]
	;
	
singleLinePreprocessorDirective
	:	PP_DEFINE^   PP_IDENT
	|	PP_UNDEFINE^ PP_IDENT
	|	lineDirective
	|	PP_ERROR^   ppMessage
	|	PP_WARNING^ ppMessage
	;
	
lineDirective
	:	PP_LINE^
		(	DEFAULT
		|	PP_NUMBER ( PP_FILENAME )?
		)
	;
	
regionDirective! [CodeMaskEnums codeMask]
	:	reg:PP_REGION^ msg1:ppMessage					{ #reg.addChildEx(#msg1); }
		drtv:directiveBlock[codeMask]					{ #reg.addChildEx(#drtv); }
		
		endreg:PP_ENDREGION msg2:ppMessage 				{
														   #endreg.addChildEx(#msg2); 
														   #reg.addChildEx(#endreg);
														}
														{ ## = #reg; }
	;

conditionalDirective! [CodeMaskEnums codeMask]
	:	hashIF:PP_COND_IF^ exprIF:preprocessExpression			{ #hashIF.addChildEx(#exprIF); }
		drtvIF:directiveBlock[codeMask]							{ #hashIF.addChildEx(#drtvIF); }
		
		(	hashELIF:PP_COND_ELIF exprELIF:preprocessExpression	{ #hashELIF.addChildEx(#exprELIF); }
			drtvELIF:directiveBlock[codeMask]					{
																  #hashELIF.addChildEx(#drtvELIF); 
 															 	  #hashIF.addChildEx(#hashELIF); 
																}
		)*
		
		(	hashELSE:PP_COND_ELSE
			drtvELSE:directiveBlock[codeMask]					{
																  #hashELSE.addChildEx(#drtvELSE); 
																  #hashIF.addChildEx(#hashELSE); 
																}
		)?
		
		hashENDIF:PP_COND_ENDIF									{ #hashIF.addChildEx(#hashENDIF); }
																{ ## = #hashIF; }
	;

directiveBlock  [CodeMaskEnums codeMask]
	:	
		(	{ NotExcluded(codeMask, CodeMaskEnums.UsingDirectives) }? 				usingDirective
		|	{ NotExcluded(codeMask, CodeMaskEnums.GlobalAttributes) }? 				globalAttributeSection
		|	{ NotExcluded(codeMask, CodeMaskEnums.Attributes) }? 					attributeSection
		|	{ NotExcluded(codeMask, CodeMaskEnums.NamespaceMemberDeclarations) }? 	namespaceMemberDeclaration
		|	{ NotExcluded(codeMask, CodeMaskEnums.ClassMemberDeclarations) }? 		classMemberDeclaration
		|	{ NotExcluded(codeMask, CodeMaskEnums.StructMemberDeclarations) }? 		structMemberDeclaration
		|	{ NotExcluded(codeMask, CodeMaskEnums.InterfaceMemberDeclarations) }? 	interfaceMemberDeclaration
		|	{ NotExcluded(codeMask, CodeMaskEnums.Statements) }? 					statement
		|	preprocessorDirective[codeMask]
		)*
		{ ## = #( [PP_BLOCK, "PP_BLOCK"], ## ); }
	;
	
ppMessage
	:	( PP_IDENT | PP_STRING | PP_FILENAME | PP_NUMBER )*
		{ ## = #( [PP_MESSAGE, "PP_MESSAGE"], ## ); }
	;
	
	
//======================================
// 14.2.1 Operator precedence and associativity
//
// The following table summarizes all PP operators in order of precedence from lowest to highest:
//
// PRECEDENCE     SECTION  CATEGORY                     OPERATORS
//  lowest  ( 4)  14.11    Conditional OR               ||
//          ( 3)  14.11    Conditional AND              &&
//          ( 2)  14.9     Equality                     == !=
//  highest ( 1)  14.5     Primary                      (x) !x
//
// NOTE: In accordance with lessons gleaned from the "java.g" file supplied with ANTLR, I have
//       applied the following pattern to the rules for expressions:
// 
//           thisLevelExpression :
//               nextHigherPrecedenceExpression (OPERATOR nextHigherPrecedenceExpression)*
//
//       which is a standard recursive definition for a parsing an expression.
//
preprocessExpression
	:	preprocessOrExpression
		{ #preprocessExpression = #( #[PP_EXPR,"PP_EXPR"], #preprocessExpression ); }
	;

preprocessOrExpression
	:	preprocessAndExpression (	LOG_OR^ preprocessAndExpression )*
	;

preprocessAndExpression
	:	preprocessEqualityExpression (	LOG_AND^ preprocessEqualityExpression )*
	;
	
preprocessEqualityExpression
	:	preprocessPrimaryExpression ( ( EQUAL^ | NOT_EQUAL^ ) preprocessPrimaryExpression )*
	;
	
preprocessPrimaryExpression
	:	(	id:keywordExceptTrueAndFalse { #id.setType(PP_IDENT); }
		|	PP_IDENT
		|	TRUE
		|	FALSE
		|	LOG_NOT^ preprocessPrimaryExpression
		|	o:OPEN_PAREN^ { #o.setType(PAREN_EXPR); } preprocessOrExpression CLOSE_PAREN!
		)
	;

keywordExceptTrueAndFalse
	:	ABSTRACT
	|	AS
	|	BASE
	|	BOOL
	|	BREAK
	|	BYTE
	|	CASE
	|	CATCH
	|	CHAR
	|	CHECKED  | CLASS    | CONST   | CONTINUE | DECIMAL   | DEFAULT  | DELEGATE
	|	DO       | DOUBLE   | ELSE    | ENUM     | EVENT     | EXPLICIT | EXTERN    
	|	FINALLY  | FIXED    | FLOAT   |	FOR      | FOREACH   | GOTO     | IF      
	|	IMPLICIT | IN       | INT     | INTERFACE| INTERNAL  | IS       | LOCK
	|	LONG     | NAMESPACE| NEW     | NULL     | OBJECT    | OPERATOR | OUT	    
	|	OVERRIDE | PARAMS   | PRIVATE | PROTECTED| PUBLIC    | READONLY       
	|	REF      | RETURN   | SBYTE   | SEALED   | SHORT     | SIZEOF   | STACKALLOC 
	|	STATIC   | STRING   | STRUCT  | SWITCH   | THIS      | THROW    | TRY     
	|	TYPEOF   | UINT     | ULONG   | UNCHECKED| UNSAFE    | USHORT   | USING   
	|	VIRTUAL  | VOID     | VOLATILE| WHILE
	;

voidAsType!
	:	v:VOID 		
		{ ## =  #( [TYPE, "TYPE"], #v, [STARS, "STARS"], [ARRAY_RANKS, "ARRAY_RANKS"] ); }
	;
