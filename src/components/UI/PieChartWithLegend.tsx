import React from 'react';
import { PieChart, Pie, Cell, Tooltip, ResponsiveContainer } from 'recharts';

interface PieChartWithLegendProps {
  data: { name: string; value: number; color: string }[];
  height?: number;
  legendPosition?: 'bottom' | 'right';
}

export const PieChartWithLegend: React.FC<PieChartWithLegendProps> = ({
  data,
  height = 260,
  legendPosition = 'bottom',
}) => {
  const total = data.reduce((sum, d) => sum + d.value, 0);

  return (
    <div className="w-full flex flex-col items-center">
      <ResponsiveContainer width="100%" height={height}>
        <PieChart>
          <Pie
            data={data}
            cx="50%"
            cy="50%"
            labelLine={false}
            outerRadius={80}
            dataKey="value"
            label={({ name, percent }) =>
              `${name}: ${(percent * 100).toFixed(0)}%`
            }
          >
            {data.map((entry, index) => (
              <Cell key={`cell-${index}`} fill={entry.color} />
            ))}
          </Pie>
          <Tooltip
            formatter={(value: number, name: string) => [
              `${((value as number) / total * 100).toFixed(1)}%`,
              name,
            ]}
          />
        </PieChart>
      </ResponsiveContainer>
      {/* Legenda */}
      <div className={`flex flex-wrap gap-4 mt-4 justify-center ${legendPosition === 'right' ? 'flex-col items-start' : ''}`}>
        {data.map((entry) => (
          <div key={entry.name} className="flex items-center gap-2 text-sm">
            <span
              className="inline-block w-4 h-4 rounded"
              style={{ backgroundColor: entry.color }}
            />
            <span style={{ color: entry.color, fontWeight: 500 }}>{entry.name}</span>
          </div>
        ))}
      </div>
    </div>
  );
};

export default PieChartWithLegend; 