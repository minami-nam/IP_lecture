const messages = document.querySelector("#messages");
const form = document.querySelector("#chatForm");
const input = document.querySelector("#messageInput");
const sendButton = document.querySelector("#sendButton");
const clearButton = document.querySelector("#clearButton");
const themeButton = document.querySelector("#themeButton");
const evidenceToggle = document.querySelector("#evidenceToggle");
const debugToggle = document.querySelector("#debugToggle");
const evidenceBox = document.querySelector("#evidenceBox");
const shell = document.querySelector(".shell");

const SESSION_STORAGE_KEY = "jinju.sessionId";

function makeSessionId() {
  if (globalThis.crypto && globalThis.crypto.randomUUID) {
    return globalThis.crypto.randomUUID();
  }
  return `${Date.now().toString(36)}-${Math.random().toString(36).slice(2)}`;
}

let sessionId = localStorage.getItem(SESSION_STORAGE_KEY) || makeSessionId();
localStorage.setItem(SESSION_STORAGE_KEY, sessionId);

const settings = {
  dark: localStorage.getItem("jinju.dark") === "true",
  evidence: localStorage.getItem("jinju.evidence") !== "false",
  debug: localStorage.getItem("jinju.debug") === "true",
};

function applySettings() {
  document.body.classList.toggle("dark", settings.dark);
  shell.classList.toggle("evidence-hidden", !settings.evidence);
  themeButton.textContent = settings.dark ? "라이트 모드" : "다크 모드";
  evidenceToggle.textContent = settings.evidence ? "근거 숨김" : "근거 표시";
  debugToggle.textContent = settings.debug ? "디버그 켜짐" : "디버그 꺼짐";
  evidenceToggle.setAttribute("aria-pressed", String(settings.evidence));
  debugToggle.setAttribute("aria-pressed", String(settings.debug));
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
  return row;
}

function formatEvidence(data) {
  const evidence = data.evidence;
  if (!evidence) return "조회 근거가 없습니다.";
  const selected = evidence.selected_service;
  const lines = [
    `응답 모드: ${data.mode || "template"}`,
    `문맥 사용: ${data.context_used || "없음"}`,
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

function formatDebugCandidates(data) {
  const matches = data.evidence && data.evidence.matches ? data.evidence.matches : [];
  if (!matches.length) return "후보 없음";
  return matches
    .slice(0, 5)
    .map((match, index) => {
      const service = match.service || {};
      const score = Number(match.score || 0).toFixed(3);
      const alias = match.matched_alias ? ` / alias: ${match.matched_alias}` : "";
      return `${index + 1}. ${service.service_name || "이름 없음"} (${score})${alias}`;
    })
    .join("\n");
}

async function sendFeedback(responseId, rating) {
  const response = await fetch("/api/feedback", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ session_id: sessionId, response_id: responseId, rating }),
  });
  const data = await response.json();
  if (!response.ok) {
    throw new Error(data.error || "피드백을 기록하지 못했습니다.");
  }
  return data;
}

function attachDebugPanel(row, data) {
  if (!settings.debug || !data.response_id) return;

  const panel = document.createElement("div");
  panel.className = "debug-panel";

  const title = document.createElement("div");
  title.className = "debug-title";
  title.textContent = "디버그";
  panel.appendChild(title);

  const candidates = document.createElement("pre");
  candidates.className = "debug-candidates";
  candidates.textContent = `후보군\n${formatDebugCandidates(data)}\n\n실제 답변\n${data.answer}`;
  panel.appendChild(candidates);

  const actions = document.createElement("div");
  actions.className = "feedback-actions";

  const status = document.createElement("span");
  status.className = "feedback-status";

  const goodButton = document.createElement("button");
  goodButton.className = "feedback-button positive";
  goodButton.type = "button";
  goodButton.textContent = "좋아요";

  const badButton = document.createElement("button");
  badButton.className = "feedback-button negative";
  badButton.type = "button";
  badButton.textContent = "싫어요";

  async function submit(rating) {
    goodButton.disabled = true;
    badButton.disabled = true;
    status.textContent = "기록 중...";
    try {
      const result = await sendFeedback(data.response_id, rating);
      status.textContent = result.message || "기록했습니다.";
    } catch (error) {
      goodButton.disabled = false;
      badButton.disabled = false;
      status.textContent = error.message;
    }
  }

  goodButton.addEventListener("click", () => submit("good"));
  badButton.addEventListener("click", () => submit("bad"));

  actions.appendChild(goodButton);
  actions.appendChild(badButton);
  actions.appendChild(status);
  panel.appendChild(actions);
  row.appendChild(panel);
  messages.scrollTop = messages.scrollHeight;
}

async function sendMessage(message) {
  const response = await fetch("/api/chat", {
    method: "POST",
    headers: { "Content-Type": "application/json" },
    body: JSON.stringify({ message, session_id: sessionId, debug_mode: settings.debug }),
  });
  const data = await response.json();
  if (data.session_id) {
    sessionId = data.session_id;
    localStorage.setItem(SESSION_STORAGE_KEY, sessionId);
  }
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
  const pending = addMessage("assistant", "확인하고 있습니다...");

  try {
    const data = await sendMessage(message);
    pending.querySelector(".bubble").textContent = data.answer;
    evidenceBox.textContent = formatEvidence(data);
    attachDebugPanel(pending, data);
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

debugToggle.addEventListener("click", () => {
  settings.debug = !settings.debug;
  localStorage.setItem("jinju.debug", String(settings.debug));
  applySettings();
});

clearButton.addEventListener("click", () => {
  messages.innerHTML = "";
  sessionId = makeSessionId();
  localStorage.setItem(SESSION_STORAGE_KEY, sessionId);
  evidenceBox.textContent = "질문을 보내면 선택 업무와 후보가 표시됩니다.";
  input.focus();
});

addMessage("assistant", "안녕하세요. 어떤 민원 업무를 확인해 드릴까요?");
