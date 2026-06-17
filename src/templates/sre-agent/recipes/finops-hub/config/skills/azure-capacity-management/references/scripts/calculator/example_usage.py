#!/usr/bin/env python3
"""
Example usage of the LLM-optimized calculator module.
Demonstrates how to integrate the calculator into LLM agents or other Python applications.
"""

from calculator import calculate


def main():
    print("LLM-Optimized Calculator Examples\n" + "=" * 50 + "\n")

    # Example 1: Basic arithmetic
    print("Example 1: Basic Arithmetic")
    expressions = [
        "2 + 2",
        "10 * 5 + 3",
        "100 / 4",
        "2^8",
    ]
    for expr in expressions:
        result = calculate(expr)
        print(f"  {expr:20s} = {result}")
    print()

    # Example 2: Mathematical functions
    print("Example 2: Mathematical Functions")
    expressions = [
        "sqrt(144)",
        "sin(pi/2)",
        "cos(pi)",
        "log(100, 10)",
        "factorial(5)",
    ]
    for expr in expressions:
        result = calculate(expr)
        print(f"  {expr:20s} = {result}")
    print()

    # Example 3: Symbolic expressions
    print("Example 3: Symbolic Expressions")
    symbolic_exprs = [
        "x^2 + 2*x + 1",
        "sin(x) + cos(x)",
        "(a + b)^2",
    ]
    for expr in symbolic_exprs:
        result = calculate(expr, symbolic=True)
        print(f"  {expr:20s} = {result}")
    print()

    # Example 4: Complex calculations
    print("Example 4: Complex Calculations")
    expressions = [
        "(sin(pi/4))^2 + (cos(pi/4))^2",
        "log(1000, 10) + sqrt(144)",
        "factorial(6) / factorial(4)",
    ]
    for expr in expressions:
        result = calculate(expr)
        print(f"  {expr:35s} = {result}")
    print()

    # Example 5: High precision
    print("Example 5: High Precision (50 decimal places)")
    result = calculate("pi", precision=50)
    print(f"  pi = {result}")
    print()

    # Example 6: Error handling
    print("Example 6: Error Handling")
    bad_expressions = [
        "1 / 0",
        "invalid expression",
        "sqrt(-1)",  # This will return I (imaginary unit) in SymPy
    ]
    for expr in bad_expressions:
        result = calculate(expr)
        print(f"  {expr:20s} = {result}")
    print()

    # Example 7: LLM tool integration pattern
    print("Example 7: LLM Tool Integration Pattern")
    print("  Simulating LLM generating math expressions...")

    # Simulate LLM outputs
    llm_outputs = [
        "What is the square root of 256?",  # Extract: sqrt(256)
        "Calculate 15 factorial",  # Extract: factorial(15)
        "What's sin(30 degrees)?",  # Convert: sin(30*pi/180)
    ]

    # In a real LLM integration, you'd have the LLM extract/convert to expressions
    extracted_expressions = [
        "sqrt(256)",
        "factorial(15)",
        "sin(30*pi/180)",
    ]

    for question, expr in zip(llm_outputs, extracted_expressions):
        result = calculate(expr)
        print(f"  Q: {question}")
        print(f"  A: {result}\n")


if __name__ == "__main__":
    main()
