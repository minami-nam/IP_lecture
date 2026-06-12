from __future__ import annotations

import argparse
import json
import sqlite3
from pathlib import Path
from typing import Iterable

try:
    from .tools import ServiceRecord, fee_detail_text, license_tax_detail_text, render_basic_answer, special_notice_text, topic_particle
except ImportError:
    from tools import ServiceRecord, fee_detail_text, license_tax_detail_text, render_basic_answer, special_notice_text, topic_particle


SYSTEM_PROMPT = (
    "진주시 민원 응대 챗봇입니다. 조회 근거에 있는 정보만 사용해 민원인에게 직접 답변합니다. "
    "창구, 수수료, 절차, 연락처를 임의로 만들지 않습니다. "
    "민원인에게 말하듯 자연스럽고 공손한 한국어로 짧게 답변합니다."
)

# 네가 말투를 직접 더 보강하고 싶으면 아래 스타일 이름과 문장 생성 함수를 늘리면 됩니다.
STYLE_ORDER = ("direct", "polite", "friendly", "confirm", "minami")


def connect(db_path: Path | str) -> sqlite3.Connection:
    conn = sqlite3.connect(str(db_path))
    conn.row_factory = sqlite3.Row
    return conn


def row_to_service(row: sqlite3.Row) -> ServiceRecord:
    return ServiceRecord(
        service_id=row["service_id"],
        service_name=row["service_name"],
        window=row["window"],
        fee_status=row["fee_status"],
        fee_note=row["fee_note"] or "",
        reception_fee=row["reception_fee"] or "" if "reception_fee" in row.keys() else "",
        license_tax_status=row["license_tax_status"] or "unknown" if "license_tax_status" in row.keys() else "unknown",
        license_tax_note=row["license_tax_note"] or "" if "license_tax_note" in row.keys() else "",
        document_note=row["document_note"] or "",
        status_note=row["status_note"] or "",
        category=row["category"],
        department=row["department"],
        department_floor=row["department_floor"] or None if "department_floor" in row.keys() else None,
        window_floor=row["window_floor"] or None if "window_floor" in row.keys() else None,
        special_note=row["special_note"] or "" if "special_note" in row.keys() else "",
        special_type=row["special_type"] or "" if "special_type" in row.keys() else "",
        unattended_available=bool(row["unattended_available"]) if "unattended_available" in row.keys() else False,
        identity_required=bool(row["identity_required"]) if "identity_required" in row.keys() else False,
        source_file=row["source_file"],
        source_row=row["source_row"],
    )


def load_services(db_path: Path | str) -> list[ServiceRecord]:
    with connect(db_path) as conn:
        rows = conn.execute("SELECT * FROM services ORDER BY service_id").fetchall()
    return [row_to_service(row) for row in rows]


def load_aliases(db_path: Path | str, service_id: str) -> list[str]:
    with connect(db_path) as conn:
        rows = conn.execute(
            """
            SELECT alias
            FROM aliases
            WHERE service_id = ?
            ORDER BY
                CASE
                    WHEN source = 'route_aliases.json' THEN 0
                    WHEN source = 'service_name_derived' THEN 1
                    WHEN source = 'service_name_compact' THEN 2
                    WHEN source = 'service_name' THEN 3
                    ELSE 4
                END,
                length(alias),
                alias_id
            """,
            (service_id,),
        ).fetchall()
    return [row["alias"] for row in rows]


def required_label(status: str, label: str) -> str:
    return {
        "required": f"{label} 납부가 필요한 민원",
        "not_required": f"{label} 납부가 필요하지 않은 민원",
        "conditional": f"조건에 따라 {label}가 달라질 수 있는 민원",
        "unknown": f"{label} 납부 여부가 자료에서 명확하지 않은 민원",
    }.get(status, f"{label} 납부 여부가 자료에서 명확하지 않은 민원")


def fee_label(status: str) -> str:
    return required_label(status, "수수료")


def evidence_fee_note(service: ServiceRecord) -> str:
    note = (service.fee_note or "").strip()
    if not note:
        return "자료 없음"
    redundant_notes = {
        "수수료 납부가 필요한 민원으로 표시되어 있습니다.",
        "접수 수수료가 필요하지 않은 민원으로 표시되어 있습니다.",
    }
    if note in redundant_notes:
        return "자료 없음"
    if service.reception_fee and note == reception_fee_text(service.reception_fee):
        return "자료 없음"
    return note


def license_tax_label(status: str) -> str:
    return required_label(status, "등록면허세")


def evidence_license_tax_note(service) -> str:
    note = (service.license_tax_note or "").strip()
    if not note:
        return "자료 없음"
    redundant_notes = {
        "등록면허세 납부가 필요한 민원으로 표시되어 있습니다.",
        "등록면허세 납부가 필요하지 않은 민원으로 표시되어 있습니다.",
    }
    if note in redundant_notes:
        return "자료 없음"
    return note


def floor_answer_target(service: ServiceRecord) -> str:
    if service.department and service.department_floor:
        return f"{service.department} {service.department_floor}"
    if service.department:
        return service.department
    if service.window_floor:
        return service.window_floor
    return "자료 없음"


def evidence_block(service: ServiceRecord, intent: str) -> str:
    return "\n".join(
        [
            f"질문 의도: {intent}",
            f"요청 정보: {intent}",
            f"target: {floor_answer_target(service)}",
            "모호 여부: 아니오",
            f"선택 업무: {service.service_name}",
            f"담당 창구: {service.window}",
            f"수수료: {fee_label(service.fee_status)}",
            f"접수 수수료: {service.reception_fee or '자료 없음'}",
            f"수수료 비고: {evidence_fee_note(service)}",
            f"등록면허세: {license_tax_label(service.license_tax_status)}",
            f"등록면허세 비고: {evidence_license_tax_note(service)}",
            f"구비서류 비고: {service.document_note or '자료 없음'}",
            f"처리 비고: {service.status_note or '자료 없음'}",
            f"특이사항: {service.special_note or '자료 없음'}",
            f"담당부서: {service.department or '자료 없음'}",
            f"담당부서 층수: {service.department_floor or '자료 없음'}",
            f"창구 부서 층수: {service.window_floor or '자료 없음'}",
            f"무인민원발급기 처리 가능: {'예' if service.unattended_available else '아니오'}",
            f"본인확인 필요: {'예' if service.identity_required else '아니오'}",
        ]
    )


def instruction(question: str, service: ServiceRecord, intent: str) -> str:
    return "\n".join(
        [
            "아래 조회 근거만 사용해 민원인에게 바로 답변하세요.",
            "답변은 1~2문장으로 작성하세요.",
            "같은 말을 반복하지 말고, 자연스럽고 공손한 한국어로 답변하세요.",
            "표 형태나 항목명은 출력하지 마세요.",
            "한자, 앱 이름, 전화번호, 조회 근거에 없는 절차와 금액은 쓰지 마세요.",
            "",
            "조회 근거",
            evidence_block(service, intent),
            "",
            f"민원인 질문: {question}",
        ]
    )


def topic(service: ServiceRecord) -> str:
    return f"{service.service_name}{topic_particle(service.service_name)}"


def clean_service_name(service: ServiceRecord) -> str:
    name = service.service_name.replace(" 관련 문의", "").strip()
    return name or service.service_name


def route_visit_sentence(service: ServiceRecord) -> str:
    if "무인민원발급기" in service.window:
        return f"{service.window}를 이용하시면 됩니다."
    return f"방문하실 때는 {service.window}로 가시면 됩니다."


def floor_notice_sentence(service: ServiceRecord) -> str:
    if service.department and service.department_floor:
        return f"실제 처리는 {service.department}에서 담당하며, {service.department_floor}에 있습니다."
    if service.department:
        return f"실제 처리는 {service.department} 담당부서 안내가 필요합니다."
    if service.window_floor:
        return f"해당 창구 부서는 {service.window_floor}에 있습니다."
    return ""


def with_floor_notice(service: ServiceRecord, text: str) -> str:
    notice = floor_notice_sentence(service)
    if notice and notice not in text:
        return f"{text} {notice}"
    return text


def route_answers(service: ServiceRecord) -> list[tuple[str, str]]:
    t = topic(service)
    clean_name = clean_service_name(service)
    return [
        ("direct", with_floor_notice(service, f"{t} {service.window}에서 안내받으시면 됩니다.")),
        ("polite", with_floor_notice(service, f"{t} {service.window}에서 안내받을 수 있습니다.")),
        ("friendly", with_floor_notice(service, f"{route_visit_sentence(service)} {clean_name} 업무로 문의하시면 안내받기 쉽습니다.")),
        ("confirm", with_floor_notice(service, f"해당 민원은 {service.window}에서 확인하시면 됩니다. 세부 사항도 같은 곳에서 안내받으시면 됩니다.")),
        ("minami", with_floor_notice(service, f"말씀하신 {t} {service.window}에서 안내받으실 수 있습니다.")),
    ]


def reception_fee_text(amount: str) -> str:
    amount = amount.strip()
    if not amount:
        return ""
    if amount.endswith("상이함"):
        return f"접수 수수료는 {amount[:-3]}상이합니다."
    return f"접수 수수료는 {amount}입니다."


def fee_answers(service: ServiceRecord) -> list[tuple[str, str]]:
    t = topic(service)
    fee_amount = f" {reception_fee_text(service.reception_fee)}" if service.reception_fee else ""
    if service.fee_status == "required":
        core = f"수수료 납부가 필요한 민원입니다.{fee_amount}"
        return [
            ("direct", f"{t} {core} 정확한 내용은 {service.window}에서 확인하시면 됩니다."),
            ("polite", f"{t} 수수료가 필요한 민원으로 확인됩니다.{fee_amount} 자세한 납부 방법은 {service.window}에서 안내받으시면 됩니다."),
            ("friendly", f"네, {t} 수수료가 필요합니다.{fee_amount} 방문하실 때 {service.window}에서 정확한 내용을 확인해 주세요."),
            ("confirm", f"자료상 {t} 수수료 납부 대상입니다.{fee_amount} 정확한 내용은 {service.window}에서 확인하시는 게 좋습니다."),
            ("minami", f"{fee_amount}이며, 금액이 부정확할 수 있으므로 {service.window}에서 정확한 금액을 확인하시길 바랍니다."),
        ]
    if service.fee_status == "not_required":
        core = "수수료 납부가 필요하지 않은 민원입니다."
        return [
            ("direct", f"{t} {core} 정확한 내용은 {service.window}에서 확인하시면 됩니다."),
            ("polite", f"{t} 수수료가 필요하지 않은 민원으로 확인됩니다. 접수 관련 내용은 {service.window}에서 안내받으시면 됩니다."),
            ("friendly", f"네, {t} 별도 수수료가 필요하지 않습니다. 방문하실 경우 {service.window}로 가시면 됩니다."),
            ("confirm", f"자료상 {t} 수수료 납부가 필요하지 않습니다. 세부 내용은 {service.window}에서 한 번 더 확인하시면 됩니다."),
            ("minami", f"말씀하신 {t} 접수 수수료가 필요하지 않습니다. 세부 사항은 {service.window}에서 한 번 더 확인바랍니다."),
        ]
    if service.fee_status == "conditional":
        note = service.fee_note or "조건에 따라 수수료가 달라질 수 있습니다."
        return [
            ("direct", f"{t} 수수료가 조건에 따라 달라질 수 있습니다. {service.window}에서 정확한 내용을 확인하시면 됩니다."),
            ("polite", f"{t} 경우에 따라 수수료가 달라질 수 있습니다. {service.window}에서 민원 내용을 기준으로 안내받으시면 됩니다."),
            ("friendly", f"이 민원은 상황에 따라 수수료가 달라질 수 있어요. {service.window}에서 접수 내용과 함께 확인해 주세요."),
            ("confirm", f"자료에는 '{note}'로 되어 있습니다. 정확한 수수료는 {service.window}에서 확인하시는 게 좋습니다."),
            ("minami", f"말씀하신 {service.service_name} 민원의 경우 경우에 따라 수수료가 달라질 수 있습니다. 자세한 사항은 {service.window}에서 확인하실 수 있습니다."),
        ]
    note = service.fee_note or "수수료 납부 여부가 자료에서 명확히 확인되지 않습니다."
    return [
        ("direct", f"{t} 수수료 납부 여부가 명확히 확인되지 않습니다. {service.window}에서 정확한 내용을 확인하시면 됩니다."),
        ("polite", f"{service.service_name}의 수수료 여부는 자료만으로는 단정하기 어렵습니다. {service.window}에서 확인해 주세요."),
        ("friendly", f"수수료는 바로 확답드리기 어렵습니다. 방문 전이나 접수 시 {service.window}에서 확인하시면 됩니다."),
        ("confirm", f"자료에는 '{note}'로 확인됩니다. 정확한 수수료 여부는 {service.window}에서 안내받으시면 됩니다."),
        ("minami", f"말씀하신 {service.service_name}의 수수료 납부 여부를 명확히 확인하기 어렵습니다. 자세한 사항은 {service.window}에서 확인하시기 바랍니다."),
    ]


def documents_answers(service: ServiceRecord) -> list[tuple[str, str]]:
    note = service.document_note or "구비서류는 자료에서 명확히 확인되지 않습니다."
    return [
        ("direct", f"{topic(service)} {service.window}에서 안내받으시면 됩니다. {note}"),
        ("polite", f"{service.service_name}의 구비서류는 {service.window}에서 민원 내용에 맞춰 확인하시면 됩니다. {note}"),
        ("friendly", f"서류는 민원 내용에 따라 달라질 수 있습니다. {service.window}에서 {service.service_name} 구비서류를 확인해 주세요."),
        ("minami", f"구비 서류의 경우, {service.window} 가 아닌 민원을 실제 처리하는 시청 내 각 부서 담당자와 통화하시면 더 빨리 답변을 들으실 수 있습니다."),
    ]


def status_answers(service: ServiceRecord) -> list[tuple[str, str]]:
    note = service.status_note or "처리 가능 여부는 담당 창구에서 확인하시면 됩니다."
    return [
        ("direct", f"{topic(service)} {service.window}에서 안내받으시면 됩니다. {note}"),
        ("polite", f"{service.service_name} 처리 가능 여부는 {service.window}에서 확인하시면 됩니다. {note}"),
        ("friendly", f"처리 가능 여부는 접수 내용에 따라 달라질 수 있습니다. {service.window}에서 확인해 주세요."),
    ]


def license_tax_answers(service: ServiceRecord) -> list[tuple[str, str]]:
    t = topic(service)
    if service.license_tax_status == "required":
        return [
            ("direct", f"{t} 등록면허세 납부가 필요한 민원입니다. 정확한 내용은 {service.window}에서 확인하시면 됩니다."),
            ("polite", f"{t} 등록면허세 납부 대상입니다. 세부 납부 방법은 {service.window}에서 안내받으시면 됩니다."),
            ("friendly", f"네, {t} 등록면허세가 필요한 것으로 확인됩니다. {service.window}에서 정확한 내용을 확인해 주세요."),
            ("minami", f"말씀하신 {t} 등록면허세 납부가 필요합니다. {service.window}에서 등록면허세를 납부하시길 바랍니다."),
        ]
    if service.license_tax_status == "not_required":
        return [
            ("direct", f"{t} 등록면허세 납부가 필요하지 않은 민원입니다. 정확한 내용은 {service.window}에서 확인하시면 됩니다."),
            ("polite", f"{t} 등록면허세가 필요하지 않은 민원으로 확인됩니다. 접수 관련 내용은 {service.window}에서 안내받으시면 됩니다."),
            ("friendly", f"네, {t} 등록면허세가 필요하지 않습니다. 방문하실 경우 {service.window}로 가시면 됩니다."),
            ("minami", f"말씀하신 {t} 등록면허세 납부가 필요하지 않습니다. 자세한 사항은 {service.window}에서 안내받으시면 됩니다."),
        ]
    note = service.license_tax_note or "등록면허세 납부 여부가 자료에서 명확히 확인되지 않습니다."
    return [
        ("direct", f"{t} 등록면허세 납부 여부가 명확히 확인되지 않습니다. {service.window}에서 정확한 내용을 확인하시면 됩니다."),
        ("polite", f"{service.service_name}의 등록면허세 여부는 자료만으로는 단정하기 어렵습니다. {service.window}에서 확인해 주세요."),
        ("confirm", f"자료에는 '{note}'로 확인됩니다. 정확한 등록면허세 여부는 {service.window}에서 안내받으시면 됩니다."),
    ]


def route_answer_text(service: ServiceRecord) -> str:
    return f"{service.window}에서 안내받으시면 됩니다."


def concise_fee_text(service: ServiceRecord) -> str:
    if service.fee_status == "required" and service.reception_fee:
        return f"수수료 납부가 필요한 민원이며, 접수 수수료는 {service.reception_fee}입니다."
    if service.fee_status == "required":
        return "수수료 납부가 필요한 민원입니다."
    if service.fee_status == "not_required":
        return "수수료 납부가 필요하지 않은 민원입니다."
    if service.fee_status == "conditional":
        return "수수료가 조건에 따라 달라질 수 있는 민원입니다."
    return "수수료 납부 여부가 자료에서 명확하지 않습니다."


def concise_license_tax_text(service: ServiceRecord) -> str:
    if service.license_tax_status == "required":
        return "등록면허세 납부가 필요한 민원입니다."
    if service.license_tax_status == "not_required":
        return "등록면허세 납부가 필요하지 않은 민원입니다."
    if service.license_tax_status == "conditional":
        return "등록면허세 납부 여부가 조건에 따라 달라질 수 있습니다."
    return "등록면허세 납부 여부가 자료에서 명확하지 않습니다."


def field_answer_text(service: ServiceRecord, field: str) -> str:
    if field == "route":
        return route_answer_text(service)
    if field == "fee":
        return concise_fee_text(service)
    if field == "license_tax":
        return concise_license_tax_text(service)
    if field == "documents":
        return service.document_note
    if field == "status":
        return service.status_note
    return route_answer_text(service)


def combined_answer(service: ServiceRecord, fields: tuple[str, ...]) -> str:
    parts = []
    for field in fields:
        text = field_answer_text(service, field)
        if text and text not in parts:
            parts.append(text)
    return f"{topic(service)} " + " ".join(parts)


def with_special_notices(service: ServiceRecord, answers: list[tuple[str, str]]) -> list[tuple[str, str]]:
    notice = special_notice_text(service, ["general"])
    if not notice:
        return answers
    updated = []
    for style, response in answers:
        text = response
        for sentence in notice.split(". "):
            sentence = sentence.strip()
            already_has_floor = bool(
                service.department
                and service.department_floor
                and service.department in text
                and service.department_floor in text
                and service.department in sentence
                and service.department_floor in sentence
            )
            if sentence and not already_has_floor and sentence not in text:
                text += f" {sentence if sentence.endswith('.') else sentence + '.'}"
        updated.append((style, text))
    return updated


def answer_variants(service: ServiceRecord, intent: str) -> list[tuple[str, str]]:
    if intent == "담당 창구 문의":
        return with_special_notices(service, route_answers(service))
    if intent == "수수료 문의":
        return with_special_notices(service, fee_answers(service))
    if intent == "등록면허세 문의":
        return with_special_notices(service, license_tax_answers(service))
    if intent == "구비서류 문의":
        return with_special_notices(service, documents_answers(service))
    if intent == "처리 가능 여부 문의":
        return with_special_notices(service, status_answers(service))
    combined_fields = {
        "창구+수수료 문의": ("route", "fee"),
        "창구+등록면허세 문의": ("route", "license_tax"),
        "수수료+등록면허세 문의": ("fee", "license_tax"),
        "창구+수수료+등록면허세 문의": ("route", "fee", "license_tax"),
        "창구+수수료+구비서류 문의": ("route", "fee", "documents"),
    }.get(intent)
    if combined_fields:
        response = combined_answer(service, combined_fields)
        return with_special_notices(service, [("combined", response)])
    return with_special_notices(service, route_answers(service))


def question_variants(service: ServiceRecord, aliases: list[str], max_names: int = 8) -> Iterable[tuple[str, str]]:
    names = [service.service_name]
    for alias in aliases:
        if alias not in names and len(names) < max_names:
            names.append(alias)

    route_templates = (
        "{name} 어디서 하니?",
        "{name} 접수는 어디에서 하나요?",
        "{name} 하려면 어느 창구로 가야 하나요?",
        "{name} 어디로 가면 돼?",
        "{name} 담당 창구 알려줘",
        "{name} 받으려면 어디 가요?",
        "{name} 하러 왔는데 몇 번 창구야?",
        "{name} 어디로 안내하면 돼?",
        "{name} 뽑으려면 어디 가요?",
        "{name} 떼려면 어디로 가면 돼?",
        "{name} 출력은 어디서 하나요?",
    )
    fee_templates = (
        "{name} 수수료 있나요?",
        "{name} 비용은 어떻게 되나요?",
        "{name} 할 때 돈 내야 해?",
        "{name} 수수료가 필요한지 알려줘",
        "{name} 접수할 때 수수료 내야 하나요?",
        "{name} 무료인가요?",
    )
    license_tax_templates = (
        "{name} 등록면허세 내야 하나요?",
        "{name} 면허세 필요한지 알려줘",
        "{name} 등록면허세도 발생하나요?",
    )
    combined_templates = (
        ("{name} 어디서 하고 수수료도 있어?", "창구+수수료 문의"),
        ("{name} 접수 창구랑 비용 알려줘", "창구+수수료 문의"),
        ("{name} 수수료랑 등록면허세 둘 다 내야 해?", "수수료+등록면허세 문의"),
        ("{name} 창구랑 등록면허세 여부 알려줘", "창구+등록면허세 문의"),
        ("{name} 어디서 접수하고 수수료랑 등록면허세도 알려줘", "창구+수수료+등록면허세 문의"),
        ("{name} 창구, 수수료, 준비서류 알려줘", "창구+수수료+구비서류 문의"),
    )

    for name in names:
        for template in route_templates:
            yield template.format(name=name), "담당 창구 문의"
        for template in fee_templates:
            yield template.format(name=name), "수수료 문의"
        for template in license_tax_templates:
            yield template.format(name=name), "등록면허세 문의"
        for template, intent in combined_templates:
            yield template.format(name=name), intent

    yield f"{service.service_name} 구비서류 알려줘", "구비서류 문의"
    yield f"{service.service_name} 준비할 서류가 있나요?", "구비서류 문의"
    yield f"{service.service_name} 처리 가능 여부 바로 알 수 있나요?", "처리 가능 여부 문의"
    yield f"{service.service_name} 지금 처리할 수 있는지 확인하고 싶어", "처리 가능 여부 문의"

def build_rows(db_path: Path | str) -> list[dict]:
    rows = []
    seen = set()
    for service in load_services(db_path):
        aliases = load_aliases(db_path, service.service_id)
        for question, intent in question_variants(service, aliases):
            for style, response in answer_variants(service, intent):
                key = (service.service_id, question, response)
                if key in seen:
                    continue
                seen.add(key)
                rows.append(
                    {
                        "system": SYSTEM_PROMPT,
                        "instruction": instruction(question, service, intent),
                        "response": response,
                        "service_id": service.service_id,
                        "service_name": service.service_name,
                        "intent": intent,
                        "style": style,
                        "target": floor_answer_target(service),
                        "department": service.department or "",
                        "department_floor": service.department_floor or "",
                        "window_floor": service.window_floor or "",
                        "source": "services.db",
                    }
                )
    return rows


def build_arg_parser() -> argparse.ArgumentParser:
    parser = argparse.ArgumentParser(description="Build evidence-grounded SFT data from services SQLite DB.")
    parser.add_argument("--db", default="data/services.db")
    parser.add_argument("--output", default="data/evidence_train.json")
    return parser


def main() -> None:
    args = build_arg_parser().parse_args()
    rows = build_rows(args.db)
    output_path = Path(args.output)
    output_path.parent.mkdir(parents=True, exist_ok=True)
    output_path.write_text(json.dumps(rows, ensure_ascii=False, indent=2), encoding="utf-8")
    print(f"[data] wrote {len(rows)} rows to {output_path}")


if __name__ == "__main__":
    main()
