export interface Database {
  public: {
    Tables: {
      tenants: {
        Row: {
          id: string;
          name: string;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          name: string;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          name?: string;
          created_at?: string;
          updated_at?: string;
        };
      };
      employees: {
        Row: {
          id: string;
          tenant_id: string;
          name: string;
          role: 'Admin' | 'Sales' | 'Mechanic' | 'User' | 'Driver' | 'Inspector';
          employee_code: string | null;
          contact_info: {
            email?: string;
            phone?: string;
            status?: string;
            updated_reason?: string;
          } | null;
          active: boolean;
          created_at: string;
          updated_at: string;
          permissions: {
            admin?: boolean;
            costs?: boolean;
            fines?: boolean;
            fleet?: boolean;
            finance?: boolean;
            contracts?: boolean;
            dashboard?: boolean;
            employees?: boolean;
            inventory?: boolean;
            purchases?: boolean;
            suppliers?: boolean;
            statistics?: boolean;
            inspections?: boolean;
            maintenance?: boolean;
          };
          roles_extra: string[] | null;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          name: string;
          role: 'Admin' | 'Sales' | 'Mechanic' | 'User' | 'Driver' | 'Inspector';
          employee_code?: string | null;
          contact_info?: {
            email?: string;
            phone?: string;
            status?: string;
            updated_reason?: string;
          } | null;
          active?: boolean;
          created_at?: string;
          updated_at?: string;
          permissions?: {
            admin?: boolean;
            costs?: boolean;
            fines?: boolean;
            fleet?: boolean;
            finance?: boolean;
            contracts?: boolean;
            dashboard?: boolean;
            employees?: boolean;
            inventory?: boolean;
            purchases?: boolean;
            suppliers?: boolean;
            statistics?: boolean;
            inspections?: boolean;
            maintenance?: boolean;
          };
          roles_extra?: string[] | null;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          name?: string;
          role?: 'Admin' | 'Sales' | 'Mechanic' | 'User' | 'Driver' | 'Inspector';
          employee_code?: string | null;
          contact_info?: {
            email?: string;
            phone?: string;
            status?: string;
            updated_reason?: string;
          } | null;
          active?: boolean;
          created_at?: string;
          updated_at?: string;
          permissions?: {
            admin?: boolean;
            costs?: boolean;
            fines?: boolean;
            fleet?: boolean;
            finance?: boolean;
            contracts?: boolean;
            dashboard?: boolean;
            employees?: boolean;
            inventory?: boolean;
            purchases?: boolean;
            suppliers?: boolean;
            statistics?: boolean;
            inspections?: boolean;
            maintenance?: boolean;
          };
          roles_extra?: string[] | null;
        };
      };
      vehicles: {
        Row: {
          id: string;
          tenant_id: string;
          plate: string;
          model: string;
          year: number;
          type: 'Furgão' | 'Van';
          color: string | null;
          fuel: 'Diesel' | 'Gasolina' | 'Elétrico' | null;
          category: string;
          chassis: string | null;
          renavam: string | null;
          cargo_capacity: number | null;
          location: string | null;
          acquisition_date: string | null;
          acquisition_value: number | null;
          mileage: number | null;
          initial_mileage: number | null;
          tank_capacity: number | null;
          current_fuel_level: number | null;
          status: 'Disponível' | 'Em Uso' | 'Manutenção' | 'Inativo' | 'No Patio';
          maintenance_status: 'Available' | 'In_Maintenance' | 'Reserved' | 'Rented';
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          plate: string;
          model: string;
          year: number;
          type: 'Furgão' | 'Van';
          color?: string | null;
          fuel?: 'Diesel' | 'Gasolina' | 'Elétrico' | null;
          category: string;
          chassis?: string | null;
          renavam?: string | null;
          cargo_capacity?: number | null;
          location?: string | null;
          acquisition_date?: string | null;
          acquisition_value?: number | null;
          mileage?: number | null;
          initial_mileage?: number | null;
          tank_capacity?: number | null;
          current_fuel_level?: number | null;
          status?: 'Disponível' | 'Em Uso' | 'Manutenção' | 'Inativo' | 'No Patio';
          maintenance_status?: 'Available' | 'In_Maintenance' | 'Reserved' | 'Rented';
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          plate?: string;
          model?: string;
          year?: number;
          type?: 'Furgão' | 'Van';
          color?: string | null;
          fuel?: 'Diesel' | 'Gasolina' | 'Elétrico' | null;
          category?: string;
          chassis?: string | null;
          renavam?: string | null;
          cargo_capacity?: number | null;
          location?: string | null;
          acquisition_date?: string | null;
          acquisition_value?: number | null;
          mileage?: number | null;
          initial_mileage?: number | null;
          tank_capacity?: number | null;
          current_fuel_level?: number | null;
          status?: 'Disponível' | 'Em Uso' | 'Manutenção' | 'Inativo' | 'No Patio';
          maintenance_status?: 'Available' | 'In_Maintenance' | 'Reserved' | 'Rented';
          created_at?: string;
          updated_at?: string;
        };
      };
      maintenance_types: {
        Row: {
          id: string;
          tenant_id: string;
          name: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          name: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          name?: string;
          created_at?: string;
        };
      };
      mechanics: {
        Row: {
          id: string;
          tenant_id: string;
          name: string;
          employee_code: string | null;
          phone: string | null;
          specialization: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          name: string;
          employee_code?: string | null;
          phone?: string | null;
          specialization?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          name?: string;
          employee_code?: string | null;
          phone?: string | null;
          specialization?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      parts: {
        Row: {
          id: string;
          tenant_id: string;
          sku: string;
          name: string;
          quantity: number;
          unit_cost: number;
          min_stock: number;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          sku: string;
          name: string;
          quantity?: number;
          unit_cost: number;
          min_stock?: number;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          sku?: string;
          name?: string;
          quantity?: number;
          unit_cost?: number;
          min_stock?: number;
          created_at?: string;
          updated_at?: string;
        };
      };
      stock_movements: {
        Row: {
          id: string;
          tenant_id: string;
          part_id: string;
          service_note_id: string | null;
          type: 'Entrada' | 'Saída';
          quantity: number;
          movement_date: string;
          created_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          part_id: string;
          service_note_id?: string | null;
          type: 'Entrada' | 'Saída';
          quantity: number;
          movement_date?: string;
          created_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          part_id?: string;
          service_note_id?: string | null;
          type?: 'Entrada' | 'Saída';
          quantity?: number;
          movement_date?: string;
          created_at?: string;
        };
      };
      service_order_parts: {
        Row: {
          id: string;
          tenant_id: string;
          service_note_id: string;
          part_id: string;
          quantity_used: number;
          unit_cost_at_time: number;
          total_cost: number;
          created_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          service_note_id: string;
          part_id: string;
          quantity_used: number;
          unit_cost_at_time: number;
          created_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          service_note_id?: string;
          part_id?: string;
          quantity_used?: number;
          unit_cost_at_time?: number;
          created_at?: string;
        };
      };
      costs: {
        Row: {
          id: string;
          tenant_id: string;
          category: 'Multa' | 'Funilaria' | 'Seguro' | 'Avulsa' | 'Compra' | 'Excesso Km' | 'Diária Extra' | 'Combustível' | 'Avaria' | 'Despesas';
          vehicle_id: string;
          description: string;
          amount: number;
          cost_date: string;
          status: 'Pendente' | 'Pago' | 'Autorizado';
          document_ref: string | null;
          observations: string | null;
          origin: 'Usuario' | 'Patio' | 'Manutencao' | 'Sistema' | 'Compras' | 'Contas' | 'salario';
          created_by_employee_id: string | null;
          source_reference_id: string | null;
          source_reference_type: 'inspection_item' | 'service_note' | 'manual' | 'system' | 'fine' | null;
          department: string | null;
          customer_id: string | null;
          customer_name: string | null;
          contract_id: string | null;
          is_recurring: boolean;
          recurrence_type: 'monthly' | 'weekly' | 'yearly' | null;
          recurrence_day: number | null;
          next_due_date: string | null;
          parent_recurring_cost_id: string | null;
          auto_generated: boolean;
          guest_id: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          category: 'Multa' | 'Funilaria' | 'Seguro' | 'Avulsa' | 'Compra' | 'Excesso Km' | 'Diária Extra' | 'Combustível' | 'Avaria' | 'Despesas';
          vehicle_id?: string | null;
          description: string;
          amount: number;
          cost_date: string;
          status?: 'Pendente' | 'Pago' | 'Autorizado';
          document_ref?: string | null;
          observations?: string | null;
          origin?: 'Usuario' | 'Patio' | 'Manutencao' | 'Sistema' | 'Compras' | 'Contas' | 'salario';
          created_by_employee_id?: string | null;
          created_by_name?: string | null;
          source_reference_id?: string | null;
          source_reference_type?: 'inspection_item' | 'service_note' | 'manual' | 'system' | 'fine' | null;
          department?: string | null;
          customer_id?: string | null;
          customer_name?: string | null;
          contract_id?: string | null;
          is_recurring?: boolean;
          recurrence_type?: 'monthly' | 'weekly' | 'yearly' | null;
          recurrence_day?: number | null;
          next_due_date?: string | null;
          parent_recurring_cost_id?: string | null;
          auto_generated?: boolean;
          guest_id?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          category?: 'Multa' | 'Funilaria' | 'Seguro' | 'Avulsa' | 'Compra' | 'Excesso Km' | 'Diária Extra' | 'Combustível' | 'Avaria' | 'Despesas';
          vehicle_id?: string;
          description?: string;
          amount?: number;
          cost_date?: string;
          status?: 'Pendente' | 'Pago' | 'Autorizado';
          document_ref?: string | null;
          observations?: string | null;
          origin?: 'Usuario' | 'Patio' | 'Manutencao' | 'Sistema' | 'Compras' | 'Contas' | 'salario';
          created_by_employee_id?: string | null;
          created_by_name?: string | null;
          source_reference_id?: string | null;
          source_reference_type?: 'inspection_item' | 'service_note' | 'manual' | 'system' | 'fine' | null;
          department?: string | null;
          customer_id?: string | null;
          customer_name?: string | null;
          contract_id?: string | null;
          is_recurring?: boolean;
          recurrence_type?: 'monthly' | 'weekly' | 'yearly' | null;
          recurrence_day?: number | null;
          next_due_date?: string | null;
          parent_recurring_cost_id?: string | null;
          auto_generated?: boolean;
          guest_id?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      service_notes: {
        Row: {
          id: string;
          tenant_id: string;
          vehicle_id: string;
          employee_id: string | null;
          maintenance_type: string;
          start_date: string;
          end_date: string | null;
          mechanic: string;
          priority: 'Baixa' | 'Média' | 'Alta';
          mileage: number | null;
          description: string;
          observations: string | null;
          status: 'Aberta' | 'Em Andamento' | 'Concluída';
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          vehicle_id: string;
          employee_id?: string | null;
          maintenance_type: string;
          start_date: string;
          end_date?: string | null;
          mechanic: string;
          priority?: 'Baixa' | 'Média' | 'Alta';
          mileage?: number | null;
          description: string;
          observations?: string | null;
          status?: 'Aberta' | 'Em Andamento' | 'Concluída';
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          vehicle_id?: string;
          employee_id?: string | null;
          maintenance_type?: string;
          start_date?: string;
          end_date?: string | null;
          mechanic?: string;
          priority?: 'Baixa' | 'Média' | 'Alta';
          mileage?: number | null;
          description?: string;
          observations?: string | null;
          status?: 'Aberta' | 'Em Andamento' | 'Concluída';
          created_at?: string;
          updated_at?: string;
        };
      };
      customers: {
        Row: {
          id: string;
          tenant_id: string;
          name: string;
          document: string;
          email: string | null;
          phone: string | null;
          address: string | null;
          active: boolean;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          name: string;
          document: string;
          email?: string | null;
          phone?: string | null;
          address?: string | null;
          active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          name?: string;
          document?: string;
          email?: string | null;
          phone?: string | null;
          address?: string | null;
          active?: boolean;
          created_at?: string;
          updated_at?: string;
        };
      };
      contracts: {
        Row: {
          id: string;
          tenant_id: string;
          customer_id: string;
          vehicle_id: string;
          salesperson_id: string | null;
          start_date: string;
          end_date: string;
          daily_rate: number;
          status: 'Ativo' | 'Finalizado' | 'Cancelado';
          km_limit: number | null;
          price_per_excess_km: number | null;
          price_per_liter: number | null;
          uses_multiple_vehicles: boolean;
          is_recurring: boolean | null;
          recurrence_type: 'monthly' | 'weekly' | 'yearly' | null;
          recurrence_day: number | null;
          auto_renew: boolean | null;
          next_renewal_date: string | null;
          guest_id: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          customer_id: string;
          vehicle_id: string;
          salesperson_id?: string | null;
          start_date: string;
          end_date: string;
          daily_rate: number;
          status?: 'Ativo' | 'Finalizado' | 'Cancelado';
          km_limit?: number | null;
          price_per_excess_km?: number | null;
          price_per_liter?: number | null;
          uses_multiple_vehicles?: boolean;
          is_recurring?: boolean | null;
          recurrence_type?: 'monthly' | 'weekly' | 'yearly' | null;
          recurrence_day?: number | null;
          auto_renew?: boolean | null;
          next_renewal_date?: string | null;
          guest_id?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          customer_id?: string;
          vehicle_id?: string;
          salesperson_id?: string | null;
          start_date?: string;
          end_date?: string;
          daily_rate?: number;
          status?: 'Ativo' | 'Finalizado' | 'Cancelado';
          km_limit?: number | null;
          price_per_excess_km?: number | null;
          price_per_liter?: number | null;
          uses_multiple_vehicles?: boolean;
          is_recurring?: boolean | null;
          recurrence_type?: 'monthly' | 'weekly' | 'yearly' | null;
          recurrence_day?: number | null;
          auto_renew?: boolean | null;
          next_renewal_date?: string | null;
          guest_id?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      contract_vehicles: {
        Row: {
          id: string;
          tenant_id: string;
          contract_id: string;
          vehicle_id: string;
          daily_rate: number | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          contract_id: string;
          vehicle_id: string;
          daily_rate?: number | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          contract_id?: string;
          vehicle_id?: string;
          daily_rate?: number | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      fines: {
        Row: {
          id: string;
          tenant_id: string;
          vehicle_id: string;
          driver_id: string | null;
          employee_id: string | null;
          fine_number: string;
          infraction_type: string;
          amount: number;
          infraction_date: string;
          due_date: string;
          notified: boolean;
          status: 'Pendente' | 'Pago' | 'Contestado';
          document_ref: string | null;
          observations: string | null;
          contract_id: string | null;
          customer_id: string | null;
          customer_name: string | null;
          severity: string | null;
          points: number | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          vehicle_id: string;
          driver_id?: string | null;
          employee_id?: string | null;
          fine_number?: string;
          infraction_type: string;
          amount: number;
          infraction_date: string;
          due_date: string;
          notified?: boolean;
          status?: 'Pendente' | 'Pago' | 'Contestado';
          document_ref?: string | null;
          observations?: string | null;
          contract_id?: string | null;
          customer_id?: string | null;
          customer_name?: string | null;
          severity?: string | null;
          points?: number | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          vehicle_id?: string;
          driver_id?: string | null;
          employee_id?: string | null;
          fine_number?: string;
          infraction_type?: string;
          amount?: number;
          infraction_date?: string;
          due_date?: string;
          notified?: boolean;
          status?: 'Pendente' | 'Pago' | 'Contestado';
          document_ref?: string | null;
          observations?: string | null;
          contract_id?: string | null;
          customer_id?: string | null;
          customer_name?: string | null;
          severity?: string | null;
          points?: number | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      inspections: {
        Row: {
          id: string;
          tenant_id: string;
          vehicle_id: string;
          inspection_type: string;
          inspected_by: string;
          inspected_at: string;
          signature_url: string | null;
          notes: string | null;
          created_at: string;
          updated_at: string;
          employee_id: string | null;
          contract_id: string | null;
          customer_id: string | null;
          mileage: number | null;
          fuel_level: number | null;
          location: string | null;
          dashboard_warning_light: boolean;
          dashboard_photo_url: string | null;
          created_by_employee_id: string | null;
          created_by_name: string | null;
        };
        Insert: {
          id?: string;
          tenant_id?: string;
          vehicle_id: string;
          inspection_type: string;
          inspected_by: string;
          inspected_at?: string;
          signature_url?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
          employee_id?: string | null;
          contract_id?: string | null;
          customer_id?: string | null;
          mileage?: number | null;
          fuel_level?: number | null;
          location?: string | null;
          dashboard_warning_light?: boolean;
          dashboard_photo_url?: string | null;
          created_by_employee_id?: string | null;
          created_by_name?: string | null;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          vehicle_id?: string;
          inspection_type?: string;
          inspected_by?: string;
          inspected_at?: string;
          signature_url?: string | null;
          notes?: string | null;
          created_at?: string;
          updated_at?: string;
          employee_id?: string | null;
          contract_id?: string | null;
          customer_id?: string | null;
          mileage?: number | null;
          fuel_level?: number | null;
          location?: string | null;
          dashboard_warning_light?: boolean;
          dashboard_photo_url?: string | null;
          created_by_employee_id?: string | null;
          created_by_name?: string | null;
        };
      };
      inspection_items: {
        Row: {
          id: string;
          inspection_id: string;
          location: string;
          description: string;
          damage_type: 'Arranhão' | 'Amassado' | 'Quebrado' | 'Desgaste' | 'Outro';
          severity: 'Baixa' | 'Média' | 'Alta';
          photo_url: string | null;
          requires_repair: boolean;
          created_at: string;
        };
        Insert: {
          id?: string;
          inspection_id: string;
          location: string;
          description: string;
          damage_type: 'Arranhão' | 'Amassado' | 'Quebrado' | 'Desgaste' | 'Outro';
          severity?: 'Baixa' | 'Média' | 'Alta';
          photo_url?: string | null;
          requires_repair?: boolean;
          created_at?: string;
        };
        Update: {
          id?: string;
          inspection_id?: string;
          location?: string;
          description?: string;
          damage_type?: 'Arranhão' | 'Amassado' | 'Quebrado' | 'Desgaste' | 'Outro';
          severity?: 'Baixa' | 'Média' | 'Alta';
          photo_url?: string | null;
          requires_repair?: boolean;
          created_at?: string;
        };
      };
      damage_notifications: {
        Row: {
          id: string;
          tenant_id: string;
          cost_id: string;
          inspection_item_id: string;
          notification_data: {
            message: string;
            recipient: string;
            metadata?: Record<string, unknown>;
          };
          status: 'pending' | 'sent' | 'failed';
          sent_at: string | null;
          error_message: string | null;
          created_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          cost_id: string;
          inspection_item_id: string;
          notification_data: {
            message: string;
            recipient: string;
            metadata?: Record<string, unknown>;
          };
          status?: 'pending' | 'sent' | 'failed';
          sent_at?: string | null;
          error_message?: string | null;
          created_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          cost_id?: string;
          inspection_item_id?: string;
          notification_data?: {
            message: string;
            recipient: string;
            metadata?: Record<string, unknown>;
          };
          status?: 'pending' | 'sent' | 'failed';
          sent_at?: string | null;
          error_message?: string | null;
          created_at?: string;
        };
      };
      drivers: {
        Row: {
          id: string;
          tenant_id: string;
          name: string;
          cpf: string | null;
          license_no: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          name: string;
          cpf?: string | null;
          license_no?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          name?: string;
          cpf?: string | null;
          license_no?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      maintenance_checkins: {
        Row: {
          id: string;
          tenant_id: string;
          service_note_id: string;
          mechanic_id: string;
          checkin_at: string;
          checkout_at: string | null;
          notes: string | null;
          signature_url: string | null;
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          service_note_id: string;
          mechanic_id: string;
          checkin_at?: string;
          checkout_at?: string | null;
          notes?: string | null;
          signature_url?: string | null;
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          service_note_id?: string;
          mechanic_id?: string;
          checkin_at?: string;
          checkout_at?: string | null;
          notes?: string | null;
          signature_url?: string | null;
          created_at?: string;
          updated_at?: string;
        };
      };
      customer_charges: {
        Row: {
          id: string;
          tenant_id: string;
          customer_id: string;
          contract_id: string;
          vehicle_id: string;
          charge_type: 'Dano' | 'Excesso KM' | 'Combustível' | 'Diária Extra' | 'Multa';
          description: string | null;
          amount: number;
          status: 'Pendente' | 'Pago' | 'Autorizado' | 'Contestado';
          charge_date: string;
          due_date: string;
          source_cost_ids: string[] | null;
          generated_from: 'Manual' | 'Automatic';
          created_at: string;
          updated_at: string;
        };
        Insert: {
          id?: string;
          tenant_id: string;
          customer_id: string;
          contract_id: string;
          vehicle_id: string;
          charge_type: 'Dano' | 'Excesso KM' | 'Combustível' | 'Diária Extra' | 'Multa';
          description?: string | null;
          amount: number;
          status?: 'Pendente' | 'Pago' | 'Autorizado' | 'Contestado';
          charge_date?: string;
          due_date: string;
          source_cost_ids?: string[] | null;
          generated_from?: 'Manual' | 'Automatic';
          created_at?: string;
          updated_at?: string;
        };
        Update: {
          id?: string;
          tenant_id?: string;
          customer_id?: string;
          contract_id?: string;
          vehicle_id?: string;
          charge_type?: 'Dano' | 'Excesso KM' | 'Combustível' | 'Diária Extra' | 'Multa';
          description?: string | null;
          amount?: number;
          status?: 'Pendente' | 'Pago' | 'Autorizado' | 'Contestado';
          charge_date?: string;
          due_date?: string;
          source_cost_ids?: string[] | null;
          generated_from?: 'Manual' | 'Automatic';
          created_at?: string;
          updated_at?: string;
        };
      };
      vw_employees_email: {
        Row: {
          id: string;
          email: string;
          active: boolean;
          status: string | null;
        };
        Insert: never;
        Update: never;
      };
      removed_users: {
        Row: RemovedUser;
        Insert: Omit<RemovedUser, 'removed_at'>;
        Update: Partial<Omit<RemovedUser, 'id' | 'removed_at'>>;
      };
      driver_vehicles: {
        Row: {
          id: string;
          driver_id: string;
          vehicle_id: string;
          assigned_at: string;
          active: boolean;
        };
        Insert: {
          id?: string;
          driver_id: string;
          vehicle_id: string;
          assigned_at?: string;
          active?: boolean;
        };
        Update: {
          id?: string;
          driver_id?: string;
          vehicle_id?: string;
          assigned_at?: string;
          active?: boolean;
        };
      };
    };
    Functions: {
      validate_session: {
        Args: Record<string, never>
        Returns: boolean
      }
      has_permission: {
        Args: { required_permission: string }
        Returns: boolean
      }
    }
  };
}

export interface RemovedUser {
  id: string;
  email: string;
  removed_at: string;
  reason: string;
}

export interface ContactInfo {
  email: string;
  phone?: string;
  address?: string;
  status?: 'active' | 'orphaned' | 'orphaned_duplicate';
  updated_reason?: string;
  metadata?: Record<string, string | number | boolean | null>;
}

export type EmployeeRole = 'Admin' | 'Inspector' | 'FineAdmin' | 'Sales';

export type Employee = Database['public']['Tables']['employees']['Row'];
export type EmployeeInsert = Database['public']['Tables']['employees']['Insert'];
export type EmployeeUpdate = Database['public']['Tables']['employees']['Update'];