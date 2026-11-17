import { expect, test } from 'claude-code/testing'

const AGORA = 1_700_000_100_000

const LINHA = {
  plugin: 'padrao',
  component: 'AgentRow',
  requestId: 'a1',
  props: {
    id: 'a1',
    description: 'ler o app',
    type: 'padrao:coletor',
    status: 'running',
    kind: 'local_agent',
    taskStatus: 'running',
    label: 'lendo\napp.py',
    startTime: AGORA - 75_000,
    cwd: '/x',
    model: 'claude-haiku-5-5',
    effort: 'medium',
    contextWindowSize: 1_000_000,
    tokenCount: 42_000,
    tokenSamples: [],
    hasRow: true,
    rowIds: ['a1'],
    isHidden: false,
  },
} as const

// Tira as cores: o teste confere o texto e, à parte, a cor que importa.
const semCor = (s: string) => s.replace(/@\[[0-9;]*m/g, '')

// Os hooks abaixo do plugin fazem o papel do Claude Code; entram uma vez, antes da primeira
// chamada em `$`. Um Text não aceita sequência de escape (só o `body` aceita): o ESC vira `@`.
function motor(on: any): void {
  on('clock.now', () => ({ value: AGORA }))
  on('ui.render', ($: any, e: any) => {
    const { Text } = $.ui.resolve(e)

    return <Text>{`[${String(e.props.body).split('\u001b').join('@')}]`}</Text>
  })
}

async function corpo($: any, props: object): Promise<string> {
  const ui = await $.ui.mount({ ...LINHA, props: { ...LINHA.props, ...props }, surface: 'terminal' })
  const texto = (await ui.find({ type: 'Text' }))?.text ?? ''
  await ui.unmount()

  return texto
}

test('a linha do coletor: tipo, modelo, effort, contexto, tempo e descrição numa linha só', async ($, on) => {
  motor(on)
  const texto = await corpo($, {})

  expect(semCor(texto)).toBe('[padrao:coletor · Haiku 5.5 · medium · ctx 4% (42k) · 1m15s · lendo app.py]')
})

test('modelo fora dos fixados sai em vermelho; o fixado, na cor da família', async ($, on) => {
  motor(on)
  expect(await corpo($, { model: 'claude-haiku-4-5' })).toContain('@[31mHaiku 4.5')
  expect(await corpo($, {})).toContain('@[32mHaiku 5.5')
})

test('Haiku acima de 100K avisa o sobrepreço; Sonnet com o mesmo contexto, não', async ($, on) => {
  motor(on)
  expect(semCor(await corpo($, { tokenCount: 150_000 }))).toContain('ctx 15% (150k) acima de 100K: 5×')
  expect(semCor(await corpo($, { tokenCount: 150_000, model: 'claude-sonnet-5-5' }))).not.toContain('acima de 100K')
})

test('custo aparece a partir de um centavo; terminado leva a marca', async ($, on) => {
  motor(on)
  const texto = semCor(await corpo($, { cost: { usd: 0.034 }, taskStatus: 'completed' }))

  expect(texto).toContain('US$ 0.03')
  expect(texto.startsWith('[✓ padrao:coletor')).toBe(true)
  expect(semCor(await corpo($, { cost: { usd: 0.001 } }))).not.toContain('US$')
})

test('sem modelo resolvido ainda e sem janela: reticências e só os tokens', async ($, on) => {
  motor(on)
  const texto = semCor(await corpo($, { model: undefined, contextWindowSize: undefined, effort: undefined }))

  expect(texto).toBe('[padrao:coletor · … · 42k tok · 1m15s · lendo app.py]')
})
