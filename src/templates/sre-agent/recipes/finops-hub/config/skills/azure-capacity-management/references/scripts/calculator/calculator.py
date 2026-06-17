#!/usr/bin/env python3
"""
LLM-Optimized Calculator using SymPy

A calculator script designed for LLM usage with safe string evaluation,
symbolic mathematics, and comprehensive mathematical operations.

Usage:
    python calculator.py "2 + 2"
    python calculator.py "sqrt(16) + 3^2"
    python calculator.py "sin(pi/2)"
    python calculator.py "x^2 + 2*x + 1" --symbolic
"""

import sys
from sympy import parse_expr, sympify, symbols, N
from sympy.parsing.sympy_parser import (
    parse_expr,
    standard_transformations,
    implicit_multiplication_application,
    convert_xor,
)


def calculate(expression: str, symbolic: bool = False, precision: int = 15) -> str:
    """
    Evaluate a mathematical expression safely using SymPy.

    Args:
        expression: String mathematical expression (e.g., "2 + 2", "sqrt(16)")
        symbolic: If True, return symbolic result; if False, evaluate numerically
        precision: Number of decimal places for numeric evaluation

    Returns:
        String representation of the result

    Examples:
        >>> calculate("2 + 2")
        '4'
        >>> calculate("sqrt(16) + 3**2")
        '13'
        >>> calculate("sin(pi/2)")
        '1.00000000000000'
        >>> calculate("x^2 + 2*x + 1", symbolic=True)
        'x**2 + 2*x + 1'
    """
    try:
        # Define transformations to make parsing more flexible
        transformations = (
            standard_transformations
            + (implicit_multiplication_application,)
            + (convert_xor,)  # Convert ^ to ** for exponentiation
        )

        # Parse the expression with transformations
        expr = parse_expr(expression, transformations=transformations)

        if symbolic or expr.free_symbols:
            # Return symbolic form if requested or if expression contains variables
            return str(expr)
        else:
            # Evaluate numerically
            result = N(expr, precision)
            return str(result)

    except Exception as e:
        return f"Error: {type(e).__name__}: {str(e)}"


def main():
    """Command-line interface for the calculator."""
    if len(sys.argv) < 2:
        print(__doc__)
        print("\nExamples:")
        print('  python calculator.py "2 + 2"')
        print('  python calculator.py "sqrt(16) + 3^2"')
        print('  python calculator.py "sin(pi/2)"')
        print('  python calculator.py "log(100, 10)"')
        print('  python calculator.py "factorial(5)"')
        print('  python calculator.py "integrate(x^2, x)" --symbolic')
        sys.exit(1)

    expression = sys.argv[1]
    symbolic = "--symbolic" in sys.argv or "-s" in sys.argv

    # Check for precision flag
    precision = 15
    for i, arg in enumerate(sys.argv):
        if arg in ["--precision", "-p"] and i + 1 < len(sys.argv):
            try:
                precision = int(sys.argv[i + 1])
            except ValueError:
                print(f"Warning: Invalid precision value '{sys.argv[i + 1]}', using default {precision}")

    result = calculate(expression, symbolic=symbolic, precision=precision)
    print(result)


if __name__ == "__main__":
    main()
