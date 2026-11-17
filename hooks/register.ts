// Linha de cada subagent no painel de agentes do padrao, como mod (hook
// `ui.render` no componente `AgentRow`). Substitui o `subagentStatusLine` do
// settings.json do plugin, que o Claude Code marcou como obsoleto.
//
//     tipo · Modelo 5.5 · effort · ctx 12% (120k) · US$ 0.03 · 1m32s · descrição
//
// Modelo fora dos que o padrao fixa sai em vermelho: a família 5.5, o Fable 5.2 e
// o Mythos 5.2 (só o `fork` de uma sessão escalada chega neles). Haiku com mais de 100K de
// contexto paga a requisição cinco vezes mais: sai o aviso em vermelho.
import type { Register } from 'claude-code'

const ESC = '\u001b['
const GREEN = `${ESC}32m`
const YELLOW = `${ESC}33m`
const RED = `${ESC}31m`
const CYAN = `${ESC}36m`
const MAGENTA = `${ESC}35m`
const BOLD = `${ESC}1m`
const RESET = `${ESC}0m`
const GRAY = `${ESC}38;5;244m`
const SEP = ` ${GRAY}·${RESET} `

const FAMILIA: Record<string, string> = { opus: MAGENTA, sonnet: CYAN, haiku: GREEN, fable: YELLOW, mythos: YELLOW }
const FIXADO: Record<string, string> = { opus: '5.5', sonnet: '5.5', haiku: '5.5', fable: '5.2', mythos: '5.2' }
const STATUS: Record<string, string> = {
  completed: `${GREEN}✓${RESET}`,
  failed: `${RED}✗${RESET}`,
  killed: `${GRAY}■${RESET}`,
}
const HAIKU_LIMITE = 100_000

type Linha = {
  type: string
  name?: string
  model?: string
  effort?: string | number
  tokenCount: number
  contextWindowSize?: number
  startTime: number
  taskStatus: string
  label: string
  cost?: { usd: number }
}

function familia(m: string | undefined): string {
  return /^claude-([a-z]+)-/.exec(m ?? '')?.[1] ?? ''
}

function modelo(m: string | undefined): string {
  if (!m) return `${GRAY}…${RESET}`
  const r = /^claude-([a-z]+)-(\d+)-(\d+)/.exec(m)
  if (!r) return `${RED}${m}${RESET}`
  const fam = r[1] ?? ''
  const maj = r[2] ?? ''
  const men = r[3] ?? ''
  const nome = `${fam.charAt(0).toUpperCase()}${fam.slice(1)} ${maj}.${men}`
  const cor = FIXADO[fam] === `${maj}.${men}` ? (FAMILIA[fam] ?? RED) : RED
  return `${BOLD}${cor}${nome}${RESET}`
}

function tokens(n: number): string {
  if (n >= 1_000_000) return `${(n / 1_000_000).toFixed(1)}M`.replace('.0M', 'M')
  return n >= 1000 ? `${Math.round(n / 1000)}k` : String(n)
}

function contexto(t: Linha): string {
  const n = t.tokenCount || 0
  const caro = familia(t.model) === 'haiku' && n > HAIKU_LIMITE ? ` ${RED}acima de 100K: 5×${RESET}` : ''
  if (!t.contextWindowSize) return `${tokens(n)} tok${caro}`
  const pct = Math.floor((n * 100) / t.contextWindowSize)
  const cor = pct >= 90 ? RED : pct >= 70 ? YELLOW : GREEN
  return `ctx ${cor}${pct}%${RESET} ${GRAY}(${tokens(n)})${RESET}${caro}`
}

function duracao(inicio: number, agora: number): string {
  if (!inicio) return ''
  const s = Math.max(0, Math.floor((agora - inicio) / 1000))
  const dois = (n: number) => String(n).padStart(2, '0')
  if (s >= 3600) return `${Math.floor(s / 3600)}h${dois(Math.floor((s % 3600) / 60))}m`
  return s >= 60 ? `${Math.floor(s / 60)}m${dois(s % 60)}s` : `${s}s`
}

export function linha(t: Linha, agora: number): string {
  const marca = STATUS[t.taskStatus]
  const partes = [`${marca ? `${marca} ` : ''}${BOLD}${t.name || t.type || 'agente'}${RESET}`, modelo(t.model)]
  if (t.effort !== undefined) partes.push(`${GRAY}${t.effort}${RESET}`)
  partes.push(contexto(t))
  if (t.cost && t.cost.usd >= 0.005) partes.push(`${GRAY}US$ ${t.cost.usd.toFixed(2)}${RESET}`)
  partes.push(duracao(t.startTime, agora))
  const descricao = (t.label || '').replace(/\s+/g, ' ').trim()
  if (descricao) partes.push(`${GRAY}${descricao}${RESET}`)
  return partes.filter(Boolean).join(SEP)
}

export const register: Register = on => {
  on('ui.render', { component: 'AgentRow' }, async ($, e, next) => {
    const agora = await $.clock.now()

    return next({ ...e, props: { ...e.props, body: linha(e.props, agora) } })
  })
}
