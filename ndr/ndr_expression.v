module ndr

import utils
import internals


// NdrExpressionType represents possible types an NDR Expression can take.
pub enum NdrExpressionType as u8
{
	fc_expr_const32 = 0x01
	fc_expr_const64 = 0x02
	fc_expr_var = 0x03
	fc_expr_oper = 0x04
	fc_expr_pad = 0x05
}

// NdrExpressionOperator contains the different operator types that can
// occur in NDR Expressions. These operators can be unary, binary or
// ternary.
pub enum NdrExpressionOperator as u8
{
	op_unary_plus = 0x01
	op_unary_minus = 0x02
	op_unary_not = 0x03
	op_unary_complement = 0x04
	op_unary_indirection = 0x05
	op_unary_cast = 0x06
	op_unary_and = 0x07
	op_unary_sizeof = 0x08
	op_unary_alignof = 0x09
	op_pre_incr = 0x0a
	op_pre_decr = 0x0b
	op_post_incr = 0x0c
	op_post_decr = 0x0d
	op_plus = 0x0e
	op_minus = 0x0f
	op_star = 0x10
	op_slash = 0x11
	op_mod = 0x12
	op_left_shift = 0x13
	op_right_shift = 0x14
	op_less = 0x15
	op_less_equal = 0x16
	op_greater_equal = 0x17
	op_greater = 0x18
	op_equal = 0x19
	op_not_equal = 0x1A
	op_and = 0x1B
	op_or = 0x1C
	op_xor = 0x1D
	op_logical_and = 0x1E
	op_logical_or = 0x1F
	op_expression = 0x20
	op_asyncsplit = 0x2B
	op_corr_pointer = 0x2C
	op_corr_top_level = 0x2D
}

// NdrBaseExpression represents the base type all other NdrExpression types
// are branched of from. It only contains the NdrExpressionType as member
// and is actually unused.
pub struct NdrBaseExpression {
	typ NdrExpressionType
}

// format returns the string representation of NdrbaseExpression. Since this
// method is not meant to be called, it returns a dummy string.
pub fn (expr NdrBaseExpression) format() string
{
	return 'BaseExpression'
}

// MaybeExpression represents the possible presence of an NDR Expression.
// This sum type contains all possible expression types as well as NdrNone
// to represent a missing expression.
type MaybeExpression = NdrBaseExpression | NdrOperatorExpression | NdrVariableExpression | NdrConstantExpression | NdrNone

// read_expression attempts to read an expression from the specified address.
// If the function succeeds, it returns the obtained expression to the caller.
// If it fails, NdrNone is returned. All possible results are wrapped in the
// MaybeExpression type. Internally, this function only inspects the first
// few bytes at the specified address and then branches of to the dedicated
// read_expression functions.
pub fn (context NdrContext) read_expression(mut addr &voidptr)! MaybeExpression
{
	typ := context.read[NdrExpressionType](mut addr)!

	match typ
	{
		.fc_expr_oper
		{
			utils.log_debug('Found operator expression at ${voidptr(*addr)})')
			return context.read_operator_expression(mut addr)!
		}

		.fc_expr_const32,
		.fc_expr_const64
		{
			utils.log_debug('Found constant expression at ${voidptr(*addr)})')
			return context.read_constant_expression(mut addr, typ)!
		}

		.fc_expr_var
		{
			utils.log_debug('Found variable expression at ${voidptr(*addr)})')
			return context.read_variable_expression(mut addr)!
		}

		else
		{
			utils.log_debug('Found base expression at ${voidptr(*addr)})')
		}
	}

	return NdrBaseExpression{}
}

// read_context_expression attempts to read an expression from the expression
// list pointed to by the MIDL_STUB_DESC.Reserved5 member. Expressions within
// this list are referenced by index, which needs to be specified to this
// function.
pub fn (context NdrContext) read_context_expression(index int)! MaybeExpression
{
	unsafe {
		expr_desc := context.read_s[internals.NDR_EXPR_DESC](context.stub_desc.Reserved5)!
		expr_offset := context.read_s[i16](voidptr(&u8(expr_desc.p_offset) + 2 * index))!

		if expr_offset < 0
		{
			return NdrBaseExpression{}
		}

		mut addr := voidptr(&u8(expr_desc.p_format_expr) + expr_offset)
		return context.read_expression(mut &addr)!
	}
}

// NdrOperatorExpression represents an expression that is based on operators.
// Depending on the operator type (unary, binary, ternary) a corresponding
// amount of arguments is required, which are stored within the arguments
// member.
pub struct NdrOperatorExpression {
	NdrBaseExpression
	operator NdrExpressionOperator
	format NdrFormatChar
	offset i16
	arguments []NdrExpression
}

// format returns the string representation of an NdrOperatorExpression.
// The function checks for the type of operator first (unary, binary or
// ternary) and then branches of to the dedicated format functions.
pub fn (op_exp NdrOperatorExpression) format() string
{
	match op_exp.operator
	{
		.op_unary_plus { return op_exp.format_unary('+') }
		.op_unary_minus { return op_exp.format_unary('-') }
		.op_unary_not { return op_exp.format_unary('!') }
		.op_unary_complement { return op_exp.format_unary('~') }
		.op_unary_indirection { return op_exp.format_unary('*') }
		.op_unary_cast { return op_exp.format_unary('(${op_exp.format})') }
		.op_unary_and { return op_exp.format_unary('') }
		.op_unary_sizeof { return op_exp.format_unary('sizeof ') }
		.op_unary_alignof { return op_exp.format_unary('alignof ') }
		.op_plus { return op_exp.format_binary('+') }
		.op_minus { return op_exp.format_binary('-') }
		.op_star { return op_exp.format_binary('*') }
		.op_slash { return op_exp.format_binary('/') }
		.op_mod { return op_exp.format_binary('%') }
		.op_left_shift { return op_exp.format_binary('<<') }
		.op_right_shift { return op_exp.format_binary('>>') }
		.op_less { return op_exp.format_binary('<') }
		.op_less_equal { return op_exp.format_binary('<=') }
		.op_greater_equal { return op_exp.format_binary('>') }
		.op_greater { return op_exp.format_binary('>=') }
		.op_equal { return op_exp.format_binary('==') }
		.op_not_equal { return op_exp.format_binary('!=') }
		.op_and { return op_exp.format_binary('&') }
		.op_or { return op_exp.format_binary('|') }
		.op_xor  { return op_exp.format_binary('^') }
		.op_logical_and { return op_exp.format_binary('&&') }
		.op_logical_or { return op_exp.format_binary('||') }
		.op_expression
		{
			args := op_exp.arguments
			return '${args[2]} ? ${args[0]} : ${args[1]}'
		}
		else { return '' }
	}
}

// format_unary returns the string representation of NdrOperatorExpression
// if the expression contains a unary operator.
pub fn (op_exp NdrOperatorExpression) format_unary(op string) string
{
	return '${op}${op_exp.arguments[0].format()}'
}

// format_binary returns the string representation of NdrOperatorExpression
// if the expression contains a binary operator.
pub fn (op_exp NdrOperatorExpression) format_binary(op string) string
{
	return '${(op_exp.arguments[0]).format()} ${op} ${(op_exp.arguments[1]).format()}'
}

// read_operator_expression attempts to read an NdrOperatorExpression from
// the specified address in process memory. If the function succeeds, the
// obtained NdrOperatorExpression is returned. Otherwise, NdrNone is returned.
// Both possible results are wrapped in MaybeExpression.
pub fn (context NdrContext) read_operator_expression(mut addr &voidptr)! MaybeExpression
{
	operator := context.read[NdrExpressionOperator](mut addr)!
	offset := context.read[i16](mut addr)!
	format := unsafe { NdrFormatChar(offset & 0xff) }

	mut arg_count := 0
	mut arguments := []NdrExpression{cap: 3}

	match operator
	{
		.op_unary_indirection,
		.op_unary_minus,
		.op_unary_plus,
		.op_unary_cast,
		.op_unary_complement,
		.op_unary_not,
		.op_unary_sizeof,
		.op_unary_alignof,
		.op_unary_and
		{
			arg_count = 1
		}

		.op_minus,
		.op_mod,
		.op_or,
		.op_plus,
		.op_slash,
		.op_star,
		.op_xor,
		.op_and,
		.op_left_shift,
		.op_right_shift,
		.op_equal,
		.op_greater,
		.op_greater_equal,
		.op_less,
		.op_less_equal,
		.op_logical_and,
		.op_logical_or,
		.op_not_equal
		{
			arg_count = 2
		}

		.op_expression
		{
			arg_count = 3
		}

		else
		{
			return NdrNone{}
		}
	}

	for ctr := 0; ctr < arg_count; ctr++
	{
		mut argument := context.read_expression(mut addr)!

		match mut argument
		{
			NdrNone,
			NdrBaseExpression
			{
				return NdrNone{}
			}

			NdrConstantExpression { arguments << argument }
			NdrVariableExpression { arguments << argument }
			NdrOperatorExpression { arguments << argument }
		}
	}

	return NdrOperatorExpression {
		typ: .fc_expr_var
		operator: operator
		format: format
		offset: offset
		arguments: arguments
	}
}

// NdrVariableExpression represents an expression that is connected to
// another variable. This connection is represented by an offset, that
// needs to be resolved when displaying the expression.
pub struct NdrVariableExpression
{
	NdrBaseExpression
	format NdrFormatChar
	offset i16
}

// format returns the string representation of an NdrVariableExpression.
// This string representation contains a placeholder, that needs to be
// replaced after resolving the variable offset.
pub fn (var_expr NdrVariableExpression) format() string
{
	return 'var{{${var_expr.offset}}}'
}

// read_variable_expression reads an NdrVariableExpression at the specified
// address from process memory. In contrast to the other read_expression
// functions, the result is no optional. If the function fails, this indicates
// an error should not be represented by an Maybe result.
pub fn (context NdrContext) read_variable_expression(mut addr &voidptr)! NdrVariableExpression
{
	format := context.read[NdrFormatChar](mut addr)!
	offset := context.read[i16](mut addr)!

	return NdrVariableExpression {
		typ: .fc_expr_var
		format: format
		offset: offset
	}
}

// NdrConstantExpression represents an expression that holds a constant value.
pub struct NdrConstantExpression
{
	NdrBaseExpression
	format NdrFormatChar
	offset i16
	value u64
}

// read_constant_expression reads an NdrConstantExpression at the specified
// address from process memory. In contrast to the other read_expression
// functions, the result is no optional. If the function fails, this indicates
// an error should not be represented by an Maybe result.
pub fn (context NdrContext) read_constant_expression(mut addr &voidptr, typ NdrExpressionType)! NdrConstantExpression
{
	format := context.read[NdrFormatChar](mut addr)!
	offset := context.read[i16](mut addr)!
	mut value := u64(0)

	if typ == .fc_expr_const32
	{
		value = context.read[u32](mut addr)!
	}

	else
	{
		value = context.read[u64](mut addr)!
	}

	return NdrConstantExpression {
		typ: typ
		value: value
		format: format
		offset: offset
	}
}

// format returns the string representation of an NdrConstantExpression.
// This expression type is simply represented by it's constant value.
pub fn (const_expr NdrConstantExpression) format() string
{
	return const_expr.value.str()
}

// NdrExpression is an interface that should be implemented by all
// expressions. It requires it's implementors to implement the
// format method, that is used to obtain the string representation
// of the associated expression.
interface NdrExpression {
	format() string
}
