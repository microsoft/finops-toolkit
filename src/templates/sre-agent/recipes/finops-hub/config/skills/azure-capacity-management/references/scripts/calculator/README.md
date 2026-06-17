# LLM-optimized calculator

A Python calculator script using **SymPy** for safe evaluation of mathematical expressions from string input—perfect for LLM usage.

## Why SymPy (not NumPy)?

- **String parsing**: Accepts natural math expressions as strings
- **Safe evaluation**: Safer than Python's `eval()`, designed for untrusted input
- **Symbolic + numeric**: Handles exact symbolic math and floating-point evaluation
- **Rich functions**: Built-in support for sqrt, sin, cos, log, factorial, etc.
- **Multiple formats**: Can parse LaTeX, natural math syntax, implicit multiplication

NumPy is for array/matrix operations, not parsing calculator-style string expressions.

## Installation

```bash
pip install sympy
# or use the requirements file
pip install -r calculator-requirements.txt
```

## Usage

### Basic arithmetic
```bash
python3 calculator.py "2 + 2"                    # 4.00000000000000
python3 calculator.py "10 * 5 + 3"               # 53.0000000000000
python3 calculator.py "100 / 4"                  # 25.0000000000000
```

### Exponentiation (use ^ or **)
```bash
python3 calculator.py "2^8"                      # 256.000000000000
python3 calculator.py "3**4"                     # 81.0000000000000
python3 calculator.py "sqrt(16) + 3^2"           # 13.0000000000000
```

### Mathematical functions
```bash
python3 calculator.py "sin(pi/2)"                # 1.00000000000000
python3 calculator.py "cos(pi)"                  # -1.00000000000000
python3 calculator.py "tan(pi/4)"                # 1.00000000000000
python3 calculator.py "log(100, 10)"             # 2.00000000000000 (log base 10)
python3 calculator.py "ln(e^2)"                  # 2.00000000000000 (natural log)
python3 calculator.py "factorial(5)"             # 120.000000000000
python3 calculator.py "sqrt(144)"                # 12.0000000000000
python3 calculator.py "abs(-42)"                 # 42.0000000000000
```

### Symbolic expressions
```bash
python3 calculator.py "x^2 + 2*x + 1" --symbolic # x**2 + 2*x + 1
python3 calculator.py "sin(x) + cos(x)" -s       # sin(x) + cos(x)
```

### Precision control
```bash
python3 calculator.py "pi" --precision 50
# 3.1415926535897932384626433832795028841971693993751
```

## LLM integration examples

### Example 1: calculator tool for an LLM agent
```python
from calculator import calculate

# LLM generates expression string
llm_output = "sqrt(144) + 5^2"
result = calculate(llm_output)
print(result)  # 37.0000000000000
```

### Example 2: safe math evaluation
```python
# User provides input (potentially unsafe)
user_input = "sin(pi/6) * 2"
result = calculate(user_input)
print(result)  # 1.00000000000000
```

### Example 3: symbolic manipulation
```python
# Preserve symbolic form
expr = "(x + 1)^2"
result = calculate(expr, symbolic=True)
print(result)  # (x + 1)**2
```

## Supported operations

### Arithmetic
- Addition: `+`
- Subtraction: `-`
- Multiplication: `*`
- Division: `/`
- Exponentiation: `^` or `**`
- Modulo: `%`

### Functions
- `sqrt(x)` - Square root
- `sin(x)`, `cos(x)`, `tan(x)` - Trigonometric
- `asin(x)`, `acos(x)`, `atan(x)` - Inverse trig
- `log(x, base)` - Logarithm (default base e)
- `ln(x)` - Natural logarithm
- `exp(x)` - Exponential (e^x)
- `factorial(n)` - Factorial
- `abs(x)` - Absolute value

### Constants
- `pi` - π (3.14159...)
- `e` - Euler's number (2.71828...)
- `oo` - Infinity

### Implicit multiplication (works automatically)
```bash
python3 calculator.py "2x + 3y"    # Requires --symbolic since x,y are variables
python3 calculator.py "2(3 + 4)"   # 14.0000000000000
```

## Features

1. **Safe evaluation**: No arbitrary code execution
2. **Flexible parsing**: Handles `^` for exponents, implicit multiplication
3. **Symbolic and numeric**: Choose between exact symbolic or numeric evaluation
4. **Error handling**: Clear error messages for invalid expressions
5. **High precision**: Configurable decimal precision

## Command-line options

- `--symbolic` or `-s`: Return symbolic result (don't evaluate numerically)
- `--precision N` or `-p N`: Set decimal precision (default: 15)

## Error handling

```bash
python3 calculator.py "1/0"
# Error: ValueError: Division by zero

python3 calculator.py "invalid expression"
# Error: SyntaxError: invalid syntax
```

## Integration with LLM tools

### As a function calling tool
```json
{
  "name": "calculate",
  "description": "Evaluate mathematical expressions safely",
  "parameters": {
    "type": "object",
    "properties": {
      "expression": {
        "type": "string",
        "description": "Mathematical expression to evaluate (e.g., 'sqrt(16) + 3^2')"
      },
      "symbolic": {
        "type": "boolean",
        "description": "Return symbolic result instead of numeric evaluation"
      }
    },
    "required": ["expression"]
  }
}
```

### Python function interface
```python
def calculate(expression: str, symbolic: bool = False, precision: int = 15) -> str:
    """
    Evaluate a mathematical expression safely using SymPy.

    Args:
        expression: String mathematical expression
        symbolic: Return symbolic result if True
        precision: Decimal places for numeric evaluation

    Returns:
        String representation of the result
    """
```

## Advanced examples

### Complex expressions
```bash
python3 calculator.py "(sin(pi/4))^2 + (cos(pi/4))^2"  # 1.00000000000000
python3 calculator.py "log(1000, 10) + sqrt(144)"      # 15.0000000000000
python3 calculator.py "factorial(6) / factorial(4)"    # 30.0000000000000
```

### Scientific notation
```bash
python3 calculator.py "1.5e10 + 2.3e9"   # 17300000000.0
```

## Why this design?

**Optimized for LLM usage:**
- LLMs output strings, not Python objects
- Simple command-line interface
- Clear error messages for debugging
- No eval() security risks
- Handles common mathematical notation naturally
- Symbolic mode for algebraic manipulation

**SymPy advantages over alternatives:**
- **vs eval()**: Much safer, no arbitrary code execution
- **vs NumPy**: NumPy requires array syntax, doesn't parse strings naturally
- **vs ast.literal_eval()**: Doesn't support mathematical functions
- **vs custom parser**: SymPy has years of battle-testing and edge case handling

## License

This calculator is part of the azcapman project.

**Source**: [SymPy documentation](https://docs.sympy.org/latest/index.html)
