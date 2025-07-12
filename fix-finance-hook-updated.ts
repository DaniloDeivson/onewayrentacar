// CORREÇÃO: Função markAsPaid atualizada para estrutura real
// Substitua a função markAsPaid no arquivo src/hooks/useFinance.ts

const markAsPaid = async (id: string) => {
  try {
    // Buscar a conta a pagar
    const { data: accountPayable, error: fetchError } = await supabase
      .from('accounts_payable')
      .select('*')
      .eq('id', id)
      .single();

    if (fetchError) throw fetchError;

    // Atualizar a conta a pagar para paga
    const { error: updateError } = await supabase
      .from('accounts_payable')
      .update({ status: 'Pago' })
      .eq('id', id);

    if (updateError) throw updateError;

    // Verificar se já existe um custo para esta conta
    const { data: existingCost, error: costCheckError } = await supabase
      .from('costs')
      .select('id')
      .eq('source_reference_id', id)
      .eq('source_reference_type', 'manual')
      .single();

    // Se já existe custo, apenas atualizar o status
    if (existingCost) {
      const { error: costUpdateError } = await supabase
        .from('costs')
        .update({ status: 'Pago' })
        .eq('id', existingCost.id);

      if (costUpdateError) {
        console.error('Erro ao atualizar custo existente:', costUpdateError);
      }

      // Atualizar cost_id na conta a pagar
      await supabase
        .from('accounts_payable')
        .update({ cost_id: existingCost.id })
        .eq('id', id);
      
      // Se a conta a pagar é de uma despesa recorrente, gerar nova conta para o próximo mês
      if (accountPayable?.category === 'Despesa Recorrente') {
        await generateNextRecurringExpense(accountPayable);
      }

      await fetchAccountsPayable();
      await fetchSalaries();
      await fetchFinancialSummary();
      return;
    }

    // Se não existe custo, criar um novo
    let costCategory = accountPayable.category;
    
    // Mapear categorias para as permitidas pela constraint
    if (costCategory === 'Despesa Recorrente') costCategory = 'Despesas';
    if (costCategory === 'Seguro') costCategory = 'Seguro';
    if (costCategory === 'Avulsa') costCategory = 'Avulsa';
    if (costCategory === 'Salário') costCategory = 'Despesas';
    
    // Se não está na lista permitida, usar 'Despesas'
    const allowedCategories = [
      'Multa', 'Funilaria', 'Seguro', 'Avulsa', 'Compra',
      'Excesso Km', 'Diária Extra', 'Combustível', 'Avaria', 'Despesas'
    ];
    if (!allowedCategories.includes(costCategory)) costCategory = 'Despesas';

    // Determinar se é recorrente
    const isRecurring = accountPayable.category === 'Despesa Recorrente' || 
                       accountPayable.category === 'Seguro' || 
                       accountPayable.category === 'Salário';

    // Criar custo
    const costData = {
      tenant_id: DEFAULT_TENANT_ID,
      category: costCategory,
      vehicle_id: null,
      description: isRecurring 
        ? `${accountPayable.category}: ${accountPayable.description}`
        : `Conta Paga: ${accountPayable.description}`,
      amount: accountPayable.amount,
      cost_date: accountPayable.due_date,
      status: 'Pago',
      document_ref: accountPayable.document_ref || `Conta Paga - ${accountPayable.category}`,
      observations: `Conta a pagar marcada como paga via Financeiro | Método: ${accountPayable.payment_method || 'Não informado'} | Vencimento: ${accountPayable.due_date}`,
      origin: 'Financeiro', // CORRIGIDO: Usar 'Financeiro' em vez de 'Usuario'
      created_by_employee_id: null,
      source_reference_id: accountPayable.id,
      source_reference_type: 'manual',
      department: 'Financeiro',
      customer_id: null,
      customer_name: null,
      contract_id: null,
      is_recurring: isRecurring,
      recurrence_type: isRecurring ? 'monthly' : null,
      recurrence_day: isRecurring ? new Date(accountPayable.due_date).getDate() : null,
      auto_generated: false
    };

    const { data: newCost, error: costError } = await supabase
      .from('costs')
      .insert([costData])
      .select()
      .single();

    if (costError) {
      console.error('Erro ao criar custo para conta paga:', costError);
      // Não falha a operação principal se o custo não for criado
    } else {
      // Atualizar cost_id na conta a pagar
      await supabase
        .from('accounts_payable')
        .update({ cost_id: newCost.id })
        .eq('id', id);
    }

    // Se a conta a pagar é de uma despesa recorrente, gerar nova conta para o próximo mês
    if (accountPayable?.category === 'Despesa Recorrente') {
      await generateNextRecurringExpense(accountPayable);
    }

    await fetchAccountsPayable();
    await fetchSalaries();
    await fetchFinancialSummary();
  } catch (error) {
    console.error('Error marking as paid:', error);
    throw error;
  }
}; 