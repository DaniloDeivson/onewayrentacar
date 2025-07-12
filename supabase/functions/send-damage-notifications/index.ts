import { serve } from 'https://deno.land/std@0.168.0/http/server.ts'
import { createClient } from 'https://esm.sh/@supabase/supabase-js@2'

const corsHeaders = {
  'Access-Control-Allow-Origin': '*',
  'Access-Control-Allow-Headers': 'authorization, x-client-info, apikey, content-type',
}

interface DamageNotification {
  id: string
  tenant_id: string
  cost_id: string
  inspection_item_id: string
  notification_data: {
    cost_id: string
    item_id: string
    inspection_id: string
    vehicle_plate: string
    vehicle_model: string
    damage_location: string
    damage_type: string
    severity: string
    description: string
    requires_repair: boolean
    timestamp: string
  }
  created_at: string
}

serve(async (req) => {
  // Handle CORS
  if (req.method === 'OPTIONS') {
    return new Response('ok', { headers: corsHeaders })
  }

  try {
    // Create Supabase client
    const supabaseClient = createClient(
      Deno.env.get('SUPABASE_URL') ?? '',
      Deno.env.get('SUPABASE_SERVICE_ROLE_KEY') ?? ''
    )

    // Get pending notifications
    const { data: notifications, error: fetchError } = await supabaseClient
      .rpc('fn_get_pending_damage_notifications')

    if (fetchError) {
      throw fetchError
    }

    const results = []

    for (const notification of notifications as DamageNotification[]) {
      try {
        // Prepare email content
        const emailData = {
          to: ['gerente@oneway.com'], // Configure with actual manager email
          subject: `🚨 DANO DETECTADO - Veículo ${notification.notification_data.vehicle_plate}`,
          html: generateEmailTemplate(notification.notification_data),
        }

        // Send email using your preferred email service
        // For this example, we'll use a placeholder
        const emailSent = await sendEmail(emailData)

        if (emailSent) {
          // Mark notification as sent
          await supabaseClient.rpc('fn_mark_notification_sent', {
            p_notification_id: notification.id
          })

          results.push({
            id: notification.id,
            status: 'sent',
            vehicle: notification.notification_data.vehicle_plate
          })
        } else {
          throw new Error('Failed to send email')
        }

      } catch (error) {
        // Mark notification as failed
        await supabaseClient.rpc('fn_mark_notification_failed', {
          p_notification_id: notification.id,
          p_error_message: error.message
        })

        results.push({
          id: notification.id,
          status: 'failed',
          error: error.message,
          vehicle: notification.notification_data.vehicle_plate
        })
      }
    }

    return new Response(
      JSON.stringify({
        success: true,
        processed: results.length,
        results: results
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 200,
      }
    )

  } catch (error) {
    return new Response(
      JSON.stringify({
        success: false,
        error: error.message
      }),
      {
        headers: { ...corsHeaders, 'Content-Type': 'application/json' },
        status: 400,
      }
    )
  }
})

function generateEmailTemplate(data: any): string {
  const severityColor = {
    'Baixa': '#10b981',
    'Média': '#f59e0b', 
    'Alta': '#ef4444'
  }[data.severity] || '#6b7280'

  return `
    <!DOCTYPE html>
    <html>
    <head>
      <meta charset="utf-8">
      <title>Dano Detectado - OneWay Rent A Car</title>
      <style>
        body { font-family: Arial, sans-serif; line-height: 1.6; color: #333; }
        .container { max-width: 600px; margin: 0 auto; padding: 20px; }
        .header { background: #1e293b; color: white; padding: 20px; text-align: center; border-radius: 8px 8px 0 0; }
        .content { background: #f8fafc; padding: 20px; border-radius: 0 0 8px 8px; }
        .alert { background: #fef2f2; border: 1px solid #fecaca; padding: 15px; border-radius: 6px; margin: 15px 0; }
        .damage-info { background: white; padding: 15px; border-radius: 6px; margin: 15px 0; }
        .severity { display: inline-block; padding: 4px 12px; border-radius: 20px; color: white; font-weight: bold; }
        .button { display: inline-block; background: #0ea5e9; color: white; padding: 12px 24px; text-decoration: none; border-radius: 6px; margin: 10px 0; }
        .footer { text-align: center; margin-top: 20px; color: #6b7280; font-size: 12px; }
      </style>
    </head>
    <body>
      <div class="container">
        <div class="header">
          <h1>🚨 DANO DETECTADO</h1>
          <p>OneWay Rent A Car - Sistema de Gestão</p>
        </div>
        
        <div class="content">
          <div class="alert">
            <strong>⚠️ ATENÇÃO:</strong> Foi detectado um dano durante a inspeção de Check-Out que requer sua análise e orçamento.
          </div>
          
          <div class="damage-info">
            <h3>📋 Detalhes do Dano</h3>
            <p><strong>Veículo:</strong> ${data.vehicle_plate} - ${data.vehicle_model}</p>
            <p><strong>Local do Dano:</strong> ${data.damage_location}</p>
            <p><strong>Tipo de Dano:</strong> ${data.damage_type}</p>
            <p><strong>Severidade:</strong> <span class="severity" style="background-color: ${severityColor}">${data.severity}</span></p>
            <p><strong>Descrição:</strong> ${data.description}</p>
            <p><strong>Requer Reparo:</strong> ${data.requires_repair ? '✅ Sim' : '❌ Não'}</p>
            <p><strong>Data/Hora:</strong> ${new Date(data.timestamp).toLocaleString('pt-BR')}</p>
          </div>
          
          <div style="text-align: center; margin: 20px 0;">
            <a href="${Deno.env.get('SUPABASE_URL')?.replace('supabase.co', 'vercel.app') || 'https://app.oneway.com'}/custos" class="button">
              💰 Acessar Painel de Custos
            </a>
          </div>
          
          <div class="alert">
            <h4>📝 Próximos Passos:</h4>
            <ol>
              <li>Acesse o painel de custos para visualizar o lançamento criado</li>
              <li>Solicite orçamento para reparo do dano</li>
              <li>Atualize o valor do custo no sistema</li>
              <li>Aprove ou rejeite o reparo conforme necessário</li>
            </ol>
          </div>
        </div>
        
        <div class="footer">
          <p>Este é um email automático do sistema OneWay Rent A Car</p>
          <p>Para dúvidas, entre em contato com o suporte técnico</p>
        </div>
      </div>
    </body>
    </html>
  `
}

async function sendEmail(emailData: any): Promise<boolean> {
  try {
    // Placeholder for email sending logic
    // You can integrate with services like:
    // - Resend
    // - SendGrid
    // - AWS SES
    // - Mailgun
    
    // For demo purposes, we'll simulate email sending
    // In production, replace this with actual email service integration
    
    // Example with Resend:
    /*
    const response = await fetch('https://api.resend.com/emails', {
      method: 'POST',
      headers: {
        'Authorization': `Bearer ${Deno.env.get('RESEND_API_KEY')}`,
        'Content-Type': 'application/json',
      },
      body: JSON.stringify({
        from: 'sistema@oneway.com',
        to: emailData.to,
        subject: emailData.subject,
        html: emailData.html,
      }),
    })
    
    return response.ok
    */
    
    // Simulate successful email sending
    await new Promise(resolve => setTimeout(resolve, 100))
    return true
    
  } catch (error) {
    return false
  }
}