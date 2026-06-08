const messages = document.querySelector("#messages");
const form = document.querySelector("#chatForm");
const input = document.querySelector("#messageInput");
const sendButton = document.querySelector("#sendButton");
const clearButton = document.querySelector("#clearButton");
const themeButton = document.querySelector("#themeButton");
const evidenceToggle = document.querySelector("#evidenceToggle");
const evidenceBox = document.querySelector("#evidenceBox");
const shell = document.querySelector(".shell");

const settings = {
  dark: localStorage.getItem("jinju.dark") === "true",
  evidence: localStorage.getItem("jinju.evidence") !== "false",
};

function applySettings() {
  document.body.classList.toggle("dark", settings.dark);
  shell.classList.toggle("evidence-hidden", !settings.evidence);
  themeButton.textContent = settings.dark ? "라이트 모드" : "다크 모드";
  evidenceToggle.textContent = settings.evidence ? "근거 숨김" : "근거 표시";
  evidenceToggle.setAttribute("aria-pressed", String(settings.evidence));
  themeButton.setAttribute("aria-pressed", String(settings.dark));
}

applySettings();

function addMessage(role, text) {
  const row = document.createElement("div");
  row.className = `message ${role}`;
  const bubble = document.createElement("div");
  bubble.className = "bubble";
  bubble.textContent = text;
  row.appendChild(bubble);
  messages.appendChild(row);
  messages.scrollTop = messages.scrollHeight;
}

function formatEvidence(data) {
  const evidence = data.evidence;
  if (!evidence) return "조회 근거가 없습니다.";
  const selected = evidence.selected_service;
  const lines = [
    `응답 모드: ${data.mode || "template"}`,
    `의도: ${evidence.intent}`,
    `신뢰도: ${Number(evidence.confidence || 0).toFixed(3)}`,
    `모호 여부: ${evidence.ambiguous ? "예" : "아니오"}`,
  ];
  if (data.warning) {
    lines.push(`경고: ${data.warning}`);
  }
  if (selected) {
    lines.push("");
    lines.push(`선택 업무: ${selected.service_name}`);
    lines.push(`담당 창구: ${selected.window}`);
    lines.push(`접수 수수료: ${selected.reception_fee || "자료 없음"}`);
    lines.push(`수수료 상태: ${selected.fee_status}`);
    lines.push(`등록면허세 상태: ${selected.license_tax_status}`);
  }
  if (evidence.matches && evidence.matches.length) {
    lines.push("");
    lines.push("후보:");
    evidence.matches.slice(0, 5).forEach((match, index) => {
      lines.push(`${index + 1}. ${match.service.service_name} (${match.score.toFixed(3)})`);
    });
  }
  if (data.public_data) {
    lines.push("");
    lines.push(`공공데이터: ${data.public_data.message}`);
    if (data.public_data.result) {
      const publicResult = data.public_data.result;
      lines.push(`공공데이터 업무명: ${publicResult.service_name}`);
      lines.push(`소관기관: ${publicResult.agency || "자료 없음"}`);
      lines.push(`출처: ${publicResult.source_url || "자료 없음"}`);
      lines.push(`조회시각: ${publicResult.fetched_at}`);
    }
  }
  return lines.join("\n");
}

async function sendMessage(message) {
  const response = await fetch("/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || "응답을 가져오지 못했습니다.");
  }
  return data;
}

form.addEventListener("submit", async (event) => {
  event.preventDefault();
  const message = input.value.trim();
  if (!message) return;

  addMessage("user", message);
  input.value = "";
  sendButton.disabled = true;
  addMessage("assistant", "확인하고 있습니다...");
  const pending = messages.lastElementChild;

  try {
    const data = await sendMessage(message);
    pending.querySelector(".bubble").textContent = data.answer;
    evidenceBox.textContent = formatEvidence(data);
  } catch (error) {
    pending.querySelector(".bubble").textContent = error.message;
  } finally {
    sendButton.disabled = false;
    input.focus();
  }
});

themeButton.addEventListener("click", () => {
  settings.dark = !settings.dark;
  localStorage.setItem("jinju.dark", String(settings.dark));
  applySettings();
});

evidenceToggle.addEventListener("click", () => {
  settings.evidence = !settings.evidence;
  localStorage.setItem("jinju.evidence", String(settings.evidence));
  applySettings();
});

clearButton.addEventListener("click", () => {
  messages.innerHTML = "";
  evidenceBox.textContent = "질문을 보내면 선택 업무와 후보가 표시됩니다.";
  input.focus();
});

addMessage("assistant", "안녕하세요. 어떤 민원 업무를 확인해 드릴까요?");
