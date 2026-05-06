# Chart artifact verification

Scheduled tasks that generate charts must validate chart artifacts with non-visual checks before embedding them in Teams messages or attaching them to reports. Visual inspection is not a reliable verification gate in autonomous runs because image-viewing tools might be unavailable.

## Required checks

For every generated chart:

1. Save the chart to a deterministic image file path.
2. Verify the file exists and has non-zero size.
3. Open the image through code, such as Pillow (`PIL.Image`) or `matplotlib.image`, to confirm it is readable.
4. Record basic metadata: image format, byte size, width, height, and color mode when available.
5. Confirm the dimensions are large enough for the intended report and that the chart title and axis labels were set before saving.
6. If any check fails, regenerate the chart once. If it still fails, omit the chart, keep the table or text summary, and state why the chart was skipped.

## Python pattern

```python
from pathlib import Path
from PIL import Image

chart_path = Path("capacity-trend.png")

if not chart_path.exists():
    raise RuntimeError(f"Chart was not created: {chart_path}")

byte_size = chart_path.stat().st_size
if byte_size <= 0:
    raise RuntimeError(f"Chart is empty: {chart_path}")

with Image.open(chart_path) as image:
    image.verify()

with Image.open(chart_path) as image:
    width, height = image.size
    metadata = {
        "path": str(chart_path),
        "bytes": byte_size,
        "format": image.format,
        "mode": image.mode,
        "width": width,
        "height": height,
    }

if width < 640 or height < 360:
    raise RuntimeError(f"Chart dimensions are too small: {metadata}")

print(metadata)
```

Use equivalent filesystem and image-library checks when Pillow is unavailable. Do not use visual inspection as the verification gate.

## Source

- Microsoft Learn, [Tools in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/tools), accessed 2026-05-02. Documents built-in code execution and visualization tools.
- Microsoft Learn, [Tutorial: Use Code Interpreter in Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/use-code-interpreter), accessed 2026-05-02. Documents generated files, chart creation, and downloadable report artifacts.
- Microsoft Learn, [Schedule tasks with Azure SRE Agent](https://learn.microsoft.com/en-us/azure/sre-agent/scheduled-tasks), accessed 2026-05-02. Documents scheduled task execution as autonomous natural-language runs.
