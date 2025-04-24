import csv
import os

def flatten_dict(d, parent_key='', sep='.'):
    items = []
    for k, v in d.items():
        new_key = f"{parent_key}{sep}{k}" if parent_key else k
        if isinstance(v, dict):
            items.extend(flatten_dict(v, new_key, sep=sep).items())
        else:
            items.append((new_key, v))
    return dict(items)

def format_markdown_table(summary: str, data: list[dict]) -> str:
    if not data:
        return summary or "No data available."

    flat_data = [flatten_dict(row) for row in data]
    keys = sorted({key for row in flat_data for key in row})

    md = f"{summary}\n\n"
    md += "| " + " | ".join(keys) + " |\n"
    md += "| " + " | ".join(["---"] * len(keys)) + " |\n"
    for row in flat_data:
        md += "| " + " | ".join(str(row.get(k, "")) for k in keys) + " |\n"
    return md

def save_csv(data: list[dict], filepath: str):
    if not data:
        print("⚠️ No data to save as CSV.")
        return

    flat_data = [flatten_dict(row) for row in data]
    keys = sorted({key for row in flat_data for key in row})

    os.makedirs(os.path.dirname(filepath), exist_ok=True)
    with open(filepath, "w", newline='', encoding="utf-8") as f:
        writer = csv.DictWriter(f, fieldnames=keys)
        writer.writeheader()
        writer.writerows(flat_data)

    print(f"✅ CSV saved to {filepath}")
