// Script de diagnóstico para o problema do submit do formulário de contratos
// Execute no console do navegador na página de contratos

console.log('🔍 Diagnóstico do problema de submit do formulário de contratos...');

// 1. Verificar se o formulário está sendo interceptado
const form = document.querySelector('form');
if (form) {
    console.log('✅ Formulário encontrado');
    
    // Verificar se há event listeners no submit
    const submitEvent = new Event('submit', { bubbles: true, cancelable: true });
    let eventIntercepted = false;
    
    const originalAddEventListener = form.addEventListener;
    form.addEventListener = function(type, listener, options) {
        if (type === 'submit') {
            console.log('📝 Event listener de submit adicionado:', listener);
        }
        return originalAddEventListener.call(this, type, listener, options);
    };
    
    // Verificar se o preventDefault está sendo chamado
    const originalPreventDefault = Event.prototype.preventDefault;
    Event.prototype.preventDefault = function() {
        if (this.type === 'submit') {
            console.log('⚠️ preventDefault chamado no submit');
            eventIntercepted = true;
        }
        return originalPreventDefault.call(this);
    };
    
} else {
    console.error('❌ Formulário não encontrado');
}

// 2. Verificar se há erros JavaScript impedindo o submit
function checkJavaScriptErrors() {
    console.log('🔍 Verificando erros JavaScript...');
    
    // Interceptar console.error
    const originalConsoleError = console.error;
    console.error = function(...args) {
        originalConsoleError.apply(console, args);
        
        const errorMessage = args.join(' ');
        if (errorMessage.includes('contract') || 
            errorMessage.includes('vehicle') || 
            errorMessage.includes('submit') ||
            errorMessage.includes('uuid') ||
            errorMessage.includes('400') ||
            errorMessage.includes('404')) {
            console.log('🚨 Erro relevante detectado:', errorMessage);
        }
    };
}

// 3. Verificar se o handleSubmit está sendo chamado
function monitorHandleSubmit() {
    console.log('🔍 Monitorando handleSubmit...');
    
    // Procurar por funções handleSubmit no escopo
    const scripts = document.querySelectorAll('script');
    scripts.forEach(script => {
        if (script.textContent.includes('handleSubmit')) {
            console.log('📝 Script com handleSubmit encontrado');
        }
    });
}

// 4. Verificar se há problemas com validação de datas
function testDateValidation() {
    console.log('🔍 Testando validação de datas...');
    
    const testCases = [
        { start: '2025-01-01', end: '2025-01-10', expected: true },
        { start: '2025-01-10', end: '2025-01-01', expected: false },
        { start: '', end: '2025-01-10', expected: false },
        { start: '2025-01-01', end: '', expected: false }
    ];
    
    testCases.forEach(testCase => {
        const start = new Date(testCase.start);
        const end = new Date(testCase.end);
        const isValid = start < end && testCase.start && testCase.end;
        
        console.log(`📅 Teste: ${testCase.start} -> ${testCase.end} = ${isValid} (esperado: ${testCase.expected})`);
    });
}

// 5. Verificar se há problemas com validação de veículos
function testVehicleValidation() {
    console.log('🔍 Testando validação de veículos...');
    
    const testCases = [
        { vehicleId: 'valid-uuid', expected: true },
        { vehicleId: '', expected: false },
        { vehicleId: null, expected: false },
        { vehicleId: undefined, expected: false }
    ];
    
    testCases.forEach(testCase => {
        const isValid = testCase.vehicleId && testCase.vehicleId.trim() !== '';
        console.log(`🚗 Teste: ${testCase.vehicleId} = ${isValid} (esperado: ${testCase.expected})`);
    });
}

// 6. Verificar se há problemas com checkContractConflicts
async function testContractConflicts() {
    console.log('🔍 Testando checkContractConflicts...');
    
    try {
        // Simular chamada com dados válidos
        const validTest = {
            vehicleIds: ['test-uuid-1', 'test-uuid-2'],
            startDate: '2025-01-01',
            endDate: '2025-01-10',
            excludeContractId: undefined
        };
        
        console.log('✅ Teste com dados válidos:', validTest);
        
        // Simular chamada com dados inválidos
        const invalidTest = {
            vehicleIds: [''],
            startDate: '2025-01-01',
            endDate: '2025-01-10',
            excludeContractId: ''
        };
        
        console.log('⚠️ Teste com dados inválidos:', invalidTest);
        
    } catch (error) {
        console.error('❌ Erro ao testar checkContractConflicts:', error);
    }
}

// 7. Verificar se há problemas com getAvailableVehicles
async function testAvailableVehicles() {
    console.log('🔍 Testando getAvailableVehicles...');
    
    try {
        // Simular chamada com datas válidas
        const validTest = {
            startDate: '2025-01-01',
            endDate: '2025-01-10',
            excludeContractId: undefined
        };
        
        console.log('✅ Teste com datas válidas:', validTest);
        
        // Simular chamada com datas inválidas
        const invalidTest = {
            startDate: '2025-01-10',
            endDate: '2025-01-01',
            excludeContractId: undefined
        };
        
        console.log('⚠️ Teste com datas inválidas:', invalidTest);
        
    } catch (error) {
        console.error('❌ Erro ao testar getAvailableVehicles:', error);
    }
}

// 8. Verificar se há problemas com o onSubmit
function testOnSubmit() {
    console.log('🔍 Testando onSubmit...');
    
    // Verificar se o onSubmit está sendo passado corretamente
    const formElements = document.querySelectorAll('[data-testid*="contract"], [class*="contract"]');
    console.log('📝 Elementos relacionados a contratos encontrados:', formElements.length);
    
    // Verificar se há funções onSubmit no escopo
    const globalFunctions = Object.keys(window).filter(key => 
        key.toLowerCase().includes('submit') || 
        key.toLowerCase().includes('contract')
    );
    
    console.log('🌐 Funções globais relacionadas:', globalFunctions);
}

// Executar diagnóstico completo
async function runDiagnosis() {
    console.log('\n🚀 Iniciando diagnóstico completo...\n');
    
    checkJavaScriptErrors();
    monitorHandleSubmit();
    testDateValidation();
    testVehicleValidation();
    await testContractConflicts();
    await testAvailableVehicles();
    testOnSubmit();
    
    console.log('\n✅ Diagnóstico concluído. Verifique os resultados acima.');
    console.log('\n💡 Próximos passos:');
    console.log('1. Execute o script fix_available_vehicles_function.sql no Supabase');
    console.log('2. Verifique se não há erros JavaScript no console');
    console.log('3. Teste o formulário com dados válidos');
    console.log('4. Verifique se o onSubmit está sendo chamado corretamente');
}

// Executar diagnóstico
runDiagnosis();

// Expor funções para uso manual
window.diagnoseContractSubmit = {
    checkJavaScriptErrors,
    monitorHandleSubmit,
    testDateValidation,
    testVehicleValidation,
    testContractConflicts,
    testAvailableVehicles,
    testOnSubmit,
    runDiagnosis
}; 