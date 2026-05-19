#!/usr/bin/env python3
import sys
import re
from datetime import datetime

def parse_results(filepath):
    results = {
        'read_only': [],
        'read_write': [],
        'write_only': []
    }
    
    current_test = None
    current_threads = None
    
    with open(filepath, 'r') as f:
        for line in f:
            # Detectar tipo de test
            if '[TEST] READ-ONLY' in line:
                current_test = 'read_only'
                match = re.search(r'(\d+) threads', line)
                current_threads = int(match.group(1)) if match else 1
            elif '[TEST] READ-WRITE' in line:
                current_test = 'read_write'
                match = re.search(r'(\d+) threads', line)
                current_threads = int(match.group(1)) if match else 1
            elif '[TEST] WRITE-ONLY' in line:
                current_test = 'write_only'
                match = re.search(r'(\d+) threads', line)
                current_threads = int(match.group(1)) if match else 1
            
            # Extraer TPS
            if 'transactions:' in line and '(' in line:
                match = re.search(r'\((\d+\.\d+) per sec\.\)', line)
                if match and current_test:
                    tps = float(match.group(1))
                    results[current_test].append({
                        'threads': current_threads,
                        'tps': tps
                    })
    
    return results

def generate_html(results, output_file):
    html = f"""
<!DOCTYPE html>
<html>
<head>
    <title>MySQL + HAProxy Benchmark Report</title>
    <script src="https://cdn.jsdelivr.net/npm/chart.js"></script>
    <style>
        body {{ font-family: Arial, sans-serif; margin: 20px; background: #f5f5f5; }}
        .container {{ max-width: 1200px; margin: 0 auto; background: white; padding: 30px; border-radius: 10px; box-shadow: 0 2px 10px rgba(0,0,0,0.1); }}
        h1 {{ color: #2E75B6; text-align: center; }}
        h2 {{ color: #404040; border-bottom: 2px solid #2E75B6; padding-bottom: 10px; }}
        .chart-container {{ margin: 30px 0; }}
        table {{ width: 100%; border-collapse: collapse; margin: 20px 0; }}
        th, td {{ padding: 12px; text-align: center; border: 1px solid #ddd; }}
        th {{ background-color: #2E75B6; color: white; }}
        tr:nth-child(even) {{ background-color: #f9f9f9; }}
        .metric {{ background: #E8F4EA; padding: 15px; margin: 10px 0; border-radius: 5px; }}
        .metric h3 {{ margin: 0; color: #2E75B6; }}
        .metric p {{ margin: 5px 0; font-size: 24px; font-weight: bold; }}
    </style>
</head>
<body>
    <div class="container">
        <h1>🚀 MySQL + HAProxy Performance Benchmark</h1>
        <p style="text-align: center; color: #666;">Generado: {datetime.now().strftime('%Y-%m-%d %H:%M:%S')}</p>
        
        <h2>📊 Resumen de Resultados</h2>
        <div style="display: grid; grid-template-columns: repeat(3, 1fr); gap: 20px;">
            <div class="metric">
                <h3>Read-Only (Esclavos)</h3>
                <p>{max([r['tps'] for r in results['read_only']]):.2f} TPS</p>
            </div>
            <div class="metric">
                <h3>Read-Write (Maestro)</h3>
                <p>{max([r['tps'] for r in results['read_write']]):.2f} TPS</p>
            </div>
            <div class="metric">
                <h3>Write-Only (Maestro)</h3>
                <p>{max([r['tps'] for r in results['write_only']]):.2f} TPS</p>
            </div>
        </div>
        
        <h2>📈 Gráfica Comparativa</h2>
        <div class="chart-container">
            <canvas id="tpsChart"></canvas>
        </div>
        
        <h2>📋 Tabla Detallada</h2>
        <table>
            <tr>
                <th>Tipo de Test</th>
                <th>Threads</th>
                <th>TPS (Transacciones/seg)</th>
            </tr>
"""
    
    for test_type, test_name in [('read_only', 'Read-Only'), ('read_write', 'Read-Write'), ('write_only', 'Write-Only')]:
        for result in results[test_type]:
            html += f"""
            <tr>
                <td>{test_name}</td>
                <td>{result['threads']}</td>
                <td><strong>{result['tps']:.2f}</strong></td>
            </tr>
"""
    
    # Preparar datos para Chart.js
    threads = sorted(set([r['threads'] for r in results['read_only']]))
    
    html += f"""
        </table>
        
        <script>
        const ctx = document.getElementById('tpsChart').getContext('2d');
        new Chart(ctx, {{
            type: 'line',
            data: {{
                labels: {threads},
                datasets: [
                    {{
                        label: 'Read-Only (Esclavos)',
                        data: {[r['tps'] for r in results['read_only']]},
                        borderColor: 'rgb(46, 117, 182)',
                        backgroundColor: 'rgba(46, 117, 182, 0.1)',
                        tension: 0.1
                    }},
                    {{
                        label: 'Read-Write (Maestro)',
                        data: {[r['tps'] for r in results['read_write']]},
                        borderColor: 'rgb(255, 99, 132)',
                        backgroundColor: 'rgba(255, 99, 132, 0.1)',
                        tension: 0.1
                    }},
                    {{
                        label: 'Write-Only (Maestro)',
                        data: {[r['tps'] for r in results['write_only']]},
                        borderColor: 'rgb(255, 205, 86)',
                        backgroundColor: 'rgba(255, 205, 86, 0.1)',
                        tension: 0.1
                    }}
                ]
            }},
            options: {{
                responsive: true,
                plugins: {{
                    title: {{
                        display: true,
                        text: 'TPS vs Número de Threads'
                    }}
                }},
                scales: {{
                    y: {{
                        beginAtZero: true,
                        title: {{
                            display: true,
                            text: 'Transacciones por Segundo (TPS)'
                        }}
                    }},
                    x: {{
                        title: {{
                            display: true,
                            text: 'Número de Threads'
                        }}
                    }}
                }}
            }}
        }});
        </script>
    </div>
</body>
</html>
"""
    
    # Guardar HTML
    html_file = output_file.replace('.txt', '.html')
    with open(html_file, 'w') as f:
        f.write(html)
    
    print(f"✓ Reporte HTML generado: {html_file}")

if __name__ == '__main__':
    if len(sys.argv) < 2:
        print("Uso: python3 generate-benchmark-report.py <archivo_resultados>")
        sys.exit(1)
    
    results_file = sys.argv[1]
    results = parse_results(results_file)
    generate_html(results, results_file)