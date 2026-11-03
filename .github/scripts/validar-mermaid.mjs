// Valida os diagramas Mermaid dos .md com o parser oficial (o que o GitHub usa para desenhar).
// Só para o CI: o plugin não depende de Node.
//   npm install --no-save mermaid@11.4.1 jsdom@25.0.1
//   node .github/scripts/validar-mermaid.mjs $(git ls-files '*.md')
import { readFileSync } from 'node:fs';
import { JSDOM } from 'jsdom';

const dom = new JSDOM('<!doctype html><html><body></body></html>', { pretendToBeVisual: true });
for (const k of ['window', 'document', 'Element', 'HTMLElement', 'Node', 'DOMParser', 'XMLSerializer']) {
  const valor = k === 'window' ? dom.window : dom.window[k];
  Object.defineProperty(globalThis, k, { value: valor, configurable: true, writable: true });
}
const { default: mermaid } = await import('mermaid');
mermaid.initialize({ startOnLoad: false });

let total = 0;
let falhas = 0;
for (const arq of process.argv.slice(2)) {
  const blocos = [...readFileSync(arq, 'utf8').matchAll(/```mermaid\r?\n([\s\S]*?)```/g)];
  for (const [i, m] of blocos.entries()) {
    total++;
    try {
      await mermaid.parse(m[1]);
    } catch (e) {
      falhas++;
      console.log(`${arq} diagrama ${i + 1}: ${String(e.message || e).split('\n').slice(0, 3).join(' | ')}`);
    }
  }
}
console.log(`diagramas: ${total - falhas} de ${total} válidos`);
process.exit(falhas ? 1 : 0);
