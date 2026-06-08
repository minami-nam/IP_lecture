from __future__ import annotations

import argparse
import json
import os
from dataclasses import dataclass
from typing import Any, Iterable, Optional


@dataclass
class MetricSeries:
    train_steps: list[int]
    train_losses: list[float]
    eval_steps: list[int]
    eval_losses: list[float]
    eval_ppls: list[float]
    rows: list[dict[str, Any]]


def read_metrics(path: str) -> MetricSeries:
    rows: list[dict[str, Any]] = []
    if not os.path.isfile(path):
        return MetricSeries([], [], [], [], [], rows)

    with open(path, "r", encoding="utf-8") as f:
        for line in f:
            line = line.strip()
            if not line:
                continue
            try:
                item = json.loads(line)
            except json.JSONDecodeError:
                continue
            if isinstance(item, dict):
                rows.append(item)

    train_steps: list[int] = []
    train_losses: list[float] = []
    eval_steps: list[int] = []
    eval_losses: list[float] = []
    eval_ppls: list[float] = []
    for item in rows:
        if item.get("type") == "train" and "loss" in item and "step" in item:
            train_steps.append(int(item["step"]))
            train_losses.append(float(item["loss"]))
        elif item.get("type") == "eval" and "loss" in item and "step" in item:
            eval_steps.append(int(item["step"]))
            eval_losses.append(float(item["loss"]))
            eval_ppls.append(float(item.get("ppl", 0.0)))

    return MetricSeries(train_steps, train_losses, eval_steps, eval_losses, eval_ppls, rows)


def moving_average(values: list[float], window: int) -> list[float]:
    if window <= 1 or not values:
        return values[:]
    averaged: list[float] = []
    for idx in range(len(values)):
        start = max(0, idx - window + 1)
        chunk = values[start : idx + 1]
        averaged.append(sum(chunk) / len(chunk))
    return averaged


def summarize(series: MetricSeries) -> str:
    parts = []
    if series.train_losses:
        parts.append(
            f"train loss: first={series.train_losses[0]:.4f}, "
            f"last={series.train_losses[-1]:.4f}, points={len(series.train_losses)}"
        )
    if series.eval_losses:
        best_idx = min(range(len(series.eval_losses)), key=lambda idx: series.eval_losses[idx])
        parts.append(
            f"eval loss: last={series.eval_losses[-1]:.4f}, "
            f"best={series.eval_losses[best_idx]:.4f}@step{series.eval_steps[best_idx]}"
        )
        if series.eval_ppls:
            parts.append(f"eval ppl: last={series.eval_ppls[-1]:.2f}")
    return " | ".join(parts) if parts else "No metrics found yet."


def make_figure(metrics_file: str, smooth_window: int = 1):
    import matplotlib.pyplot as plt

    series = read_metrics(metrics_file)
    fig, axes = plt.subplots(1, 2, figsize=(12, 4.5))
    loss_ax, ppl_ax = axes

    if series.train_steps:
        loss_ax.plot(
            series.train_steps,
            moving_average(series.train_losses, smooth_window),
            label="train loss",
            color="#2563eb",
            linewidth=1.8,
        )
    if series.eval_steps:
        loss_ax.plot(
            series.eval_steps,
            series.eval_losses,
            label="eval loss",
            color="#dc2626",
            marker="o",
            linewidth=1.8,
        )
    loss_ax.set_title("Loss")
    loss_ax.set_xlabel("Step")
    loss_ax.set_ylabel("Loss")
    loss_ax.grid(True, alpha=0.25)
    loss_ax.legend(loc="best")

    if series.eval_steps and series.eval_ppls:
        ppl_ax.plot(
            series.eval_steps,
            series.eval_ppls,
            label="eval ppl",
            color="#16a34a",
            marker="o",
            linewidth=1.8,
        )
    ppl_ax.set_title("Eval Perplexity")
    ppl_ax.set_xlabel("Step")
    ppl_ax.set_ylabel("PPL")
    ppl_ax.grid(True, alpha=0.25)
    ppl_ax.legend(loc="best")

    fig.suptitle(summarize(series), fontsize=10)
    fig.tight_layout()
    return fig


def save_plot(metrics_file: str, output_file: str, smooth_window: int) -> None:
    fig = make_figure(metrics_file, smooth_window)
    os.makedirs(os.path.dirname(output_file) or ".", exist_ok=True)
    fig.savefig(output_file, dpi=160, bbox_inches="tight")
    print(f"[plot] saved={output_file}")


def table_rows(rows: Iterable[dict[str, Any]]) -> list[list[Any]]:
    table = []
    for item in rows:
        table.append(
            [
                item.get("type", ""),
                item.get("step", ""),
                item.get("epoch", ""),
                item.get("loss", ""),
                item.get("ppl", ""),
                item.get("lr", ""),
                item.get("elapsed_s", ""),
            ]
        )
    return table[-100:]


def launch_gradio(metrics_file: str, smooth_window: int, host: str, port: Optional[int]) -> None:
    import gradio as gr

    def refresh(path: str, window: int):
        series = read_metrics(path)
        fig = make_figure(path, int(window))
        return summarize(series), fig, table_rows(series.rows)

    with gr.Blocks(title="jinju_bot training metrics") as demo:
        gr.Markdown("# jinju_bot training metrics")
        with gr.Row():
            path_input = gr.Textbox(label="metrics.jsonl", value=metrics_file)
            window_input = gr.Slider(label="train loss smoothing", minimum=1, maximum=50, step=1, value=smooth_window)
            refresh_button = gr.Button("Refresh", variant="primary")
        summary = gr.Textbox(label="summary", interactive=False)
        plot = gr.Plot(label="loss / eval")
        table = gr.Dataframe(
            headers=["type", "step", "epoch", "loss", "ppl", "lr", "elapsed_s"],
            label="recent metrics",
            interactive=False,
        )
        refresh_button.click(refresh, inputs=[path_input, window_input], outputs=[summary, plot, table])
        demo.load(refresh, inputs=[path_input, window_input], outputs=[summary, plot, table])

    demo.launch(server_name=host, server_port=port)


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Visualize jinju_bot training metrics.")
    parser.add_argument("--metrics-file", default="checkpoints_evidence_Qwen2.5-1.5B-Instruct/metrics.jsonl")
    parser.add_argument("--output-file", default="checkpoints_evidence_Qwen2.5-1.5B-Instruct/metrics.png")
    parser.add_argument("--smooth-window", type=int, default=1)
    parser.add_argument("--mode", choices=("plot", "gradio"), default="gradio")
    parser.add_argument("--host", default="127.0.0.1")
    parser.add_argument("--port", type=int, default=7860)
    return parser


def main(argv: Optional[list[str]] = None) -> None:
    args = build_arg_parser().parse_args(argv)
    if args.mode == "gradio":
        launch_gradio(args.metrics_file, args.smooth_window, args.host, args.port)
    else:
        save_plot(args.metrics_file, args.output_file, args.smooth_window)


if __name__ == "__main__":
    main()
