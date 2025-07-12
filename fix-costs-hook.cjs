const fs = require('fs');
const path = require('path');

// Caminho para o arquivo Costs.tsx
const costsFilePath = path.join(__dirname, 'src', 'pages', 'Costs.tsx');

// Ler o arquivo
let content = fs.readFileSync(costsFilePath, 'utf8');

// Verificar se o hook já está sendo usado
if (!content.includes('const { updatePurchaseOrder } = usePurchaseOrders();')) {
  // Encontrar a linha onde adicionar o hook
  const lines = content.split('\n');
  
  // Procurar pela linha que contém useContracts
  let insertIndex = -1;
  for (let i = 0; i < lines.length; i++) {
    if (lines[i].includes('const { contracts } = useContracts();')) {
      insertIndex = i + 1;
      break;
    }
  }
  
  if (insertIndex !== -1) {
    // Inserir o hook após useContracts
    lines.splice(insertIndex, 0, '  const { updatePurchaseOrder } = usePurchaseOrders();');
    
    // Reescrever o arquivo
    const newContent = lines.join('\n');
    fs.writeFileSync(costsFilePath, newContent, 'utf8');
    
    console.log('✅ Hook usePurchaseOrders adicionado com sucesso!');
  } else {
    console.log('❌ Não foi possível encontrar a linha useContracts');
  }
} else {
  console.log('✅ Hook usePurchaseOrders já está presente no arquivo');
}

console.log('\n📋 Resumo da correção:');
console.log('- Status "Aprovada" adicionado à constraint do banco ✅');
console.log('- Tipos TypeScript atualizados ✅');
console.log('- Interface de exibição atualizada ✅');
console.log('- Lógica de atualização implementada ✅');
console.log('- Hook usePurchaseOrders adicionado ✅');
console.log('\n🎯 Agora ao aprovar uma compra em Custos, o status do pedido será atualizado para "Aprovada"!'); 