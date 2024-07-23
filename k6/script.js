import { sleep, check } from "k6";
import http from "k6/http";

const MODEL = __ENV.WORKER_MODEL || "llama3:8b-instruct-q4_K_M:";
const BASE_URL = __ENV.OPENAI_BASE_URL || "http://localhost:4001";
const API_KEY = __ENV.OPENAI_API_KEY;
const VUS = __ENV.VUS;
const STREAM = __ENV.STREAM || true;

export const options = {
  scenarios: {
    contacts: {
      executor: "constant-vus",
      vus: VUS,
      duration: "30s",
    },
  },
};


export const prompts = [
  "What was operation Barbarossa?",
  "Who is the best French leader in history?",
  "What ocean has the most biodiversity?",
  "What life is the in Antarctica?",
  "What is the largest industrial machine?",
];

export default function () {
  const prompt = prompts[Math.floor(Math.random() * prompts.length)];
  const params = {
    headers: {
      "Content-Type": "application/json",
      Authorization: `Bearer ${API_KEY}`,
    },
  };
  const messages = [
    {
      role: "user",
      content: prompt,
    },
  ];
  const body = JSON.stringify({
    model: MODEL,
    messages: messages,
    temperature: 0,
    stream: STREAM,
  });

  const res = http.post(`${BASE_URL}/chat/completions`, body, params);
  check(res, {
    "is status 200": (r) => r.status === 200,
  });

  sleep(1);
}
