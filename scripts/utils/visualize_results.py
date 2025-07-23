#!/usr/bin/env python3

"""
Visualize performance test results
Creates graphs and charts for comparing pre and post test results
"""

import json
import os
import sys
import glob
import argparse
import matplotlib.pyplot as plt
import matplotlib.patches as mpatches
import numpy as np
from datetime import datetime
from collections import defaultdict

# Set default style
plt.style.use('seaborn-v0_8-darkgrid')

class TestResultsVisualizer:
    def __init__(self, results_dir):
        self.results_dir = results_dir
        self.pre_results = defaultdict(dict)
        self.post_results = defaultdict(dict)
        self.figures = []
        
    def load_json_results(self):
        """Load all JSON result files"""
        json_files = glob.glob(os.path.join(self.results_dir, "*.json"))
        
        for json_file in json_files:
            filename = os.path.basename(json_file)
            
            with open(json_file, 'r') as f:
                try:
                    data = json.load(f)
                except json.JSONDecodeError:
                    print(f"Warning: Could not parse {json_file}")
                    continue
                    
            # Categorize by pre/post
            if 'pre_' in filename:
                self._categorize_result(filename, data, self.pre_results)
            elif 'post_' in filename:
                self._categorize_result(filename, data, self.post_results)
                
    def _categorize_result(self, filename, data, results_dict):
        """Categorize results by test type"""
        if 'ping' in filename:
            results_dict['ping'] = data
        elif 'iperf' in filename:
            results_dict['iperf'] = data
        elif 'dns_dig' in filename:
            results_dict['dns'] = data
        elif 'scp' in filename:
            results_dict['scp'] = data
        elif 'rsync' in filename:
            results_dict['rsync'] = data
        elif 'wget' in filename:
            results_dict['wget'] = data
        elif 'curl' in filename:
            results_dict['curl'] = data
            
    def create_ping_comparison(self):
        """Create ping latency comparison chart"""
        if not ('ping' in self.pre_results and 'ping' in self.post_results):
            return
            
        pre = self.pre_results['ping']
        post = self.post_results['ping']
        
        fig, (ax1, ax2) = plt.subplots(1, 2, figsize=(12, 5))
        
        # RTT Comparison
        categories = ['Min RTT', 'Avg RTT', 'Max RTT']
        pre_values = [
            pre.get('rtt_min_ms', 0),
            pre.get('rtt_avg_ms', 0),
            pre.get('rtt_max_ms', 0)
        ]
        post_values = [
            post.get('rtt_min_ms', 0),
            post.get('rtt_avg_ms', 0),
            post.get('rtt_max_ms', 0)
        ]
        
        x = np.arange(len(categories))
        width = 0.35
        
        bars1 = ax1.bar(x - width/2, pre_values, width, label='Pre', color='#3498db')
        bars2 = ax1.bar(x + width/2, post_values, width, label='Post', color='#e74c3c')
        
        ax1.set_xlabel('Metric')
        ax1.set_ylabel('Latency (ms)')
        ax1.set_title('Ping Latency Comparison')
        ax1.set_xticks(x)
        ax1.set_xticklabels(categories)
        ax1.legend()
        
        # Add value labels on bars
        self._add_value_labels(ax1, bars1)
        self._add_value_labels(ax1, bars2)
        
        # Packet Loss Comparison
        pre_loss = pre.get('packet_loss_percent', 0)
        post_loss = post.get('packet_loss_percent', 0)
        
        losses = [pre_loss, post_loss]
        labels = ['Pre', 'Post']
        colors = ['#3498db', '#e74c3c']
        
        bars = ax2.bar(labels, losses, color=colors)
        ax2.set_ylabel('Packet Loss (%)')
        ax2.set_title('Packet Loss Comparison')
        ax2.set_ylim(0, max(max(losses) * 1.2, 1))
        
        # Add value labels
        self._add_value_labels(ax2, bars)
        
        plt.suptitle(f"Network Latency Analysis - {pre.get('destination', 'Unknown')}", fontsize=14)
        plt.tight_layout()
        
        self.figures.append(('ping_comparison', fig))
        
    def create_throughput_comparison(self):
        """Create network throughput comparison chart"""
        # Collect all throughput data
        throughput_data = {
            'pre': {},
            'post': {}
        }
        
        # iPerf data
        if 'iperf' in self.pre_results:
            if 'speed_mbps' in self.pre_results['iperf']:
                throughput_data['pre']['iPerf3'] = self.pre_results['iperf']['speed_mbps']
            elif 'avg_mbps' in self.pre_results['iperf']:
                throughput_data['pre']['iPerf3'] = self.pre_results['iperf']['avg_mbps']
                
        if 'iperf' in self.post_results:
            if 'speed_mbps' in self.post_results['iperf']:
                throughput_data['post']['iPerf3'] = self.post_results['iperf']['speed_mbps']
            elif 'avg_mbps' in self.post_results['iperf']:
                throughput_data['post']['iPerf3'] = self.post_results['iperf']['avg_mbps']
        
        # Transfer test data
        for test_type in ['wget', 'curl', 'scp', 'rsync']:
            if test_type in self.pre_results:
                throughput_data['pre'][test_type.upper()] = self.pre_results[test_type].get('speed_mbps', 0)
            if test_type in self.post_results:
                throughput_data['post'][test_type.upper()] = self.post_results[test_type].get('speed_mbps', 0)
                
        if not throughput_data['pre'] and not throughput_data['post']:
            return
            
        fig, ax = plt.subplots(figsize=(10, 6))
        
        # Prepare data for plotting
        tests = list(set(list(throughput_data['pre'].keys()) + list(throughput_data['post'].keys())))
        pre_values = [throughput_data['pre'].get(test, 0) for test in tests]
        post_values = [throughput_data['post'].get(test, 0) for test in tests]
        
        x = np.arange(len(tests))
        width = 0.35
        
        bars1 = ax.bar(x - width/2, pre_values, width, label='Pre', color='#3498db')
        bars2 = ax.bar(x + width/2, post_values, width, label='Post', color='#2ecc71')
        
        ax.set_xlabel('Test Type')
        ax.set_ylabel('Throughput (MB/s)')
        ax.set_title('Network Throughput Comparison')
        ax.set_xticks(x)
        ax.set_xticklabels(tests)
        ax.legend()
        
        # Add value labels
        self._add_value_labels(ax, bars1)
        self._add_value_labels(ax, bars2)
        
        # Add percentage change annotations
        for i, (pre_val, post_val) in enumerate(zip(pre_values, post_values)):
            if pre_val > 0:
                change = ((post_val - pre_val) / pre_val) * 100
                color = 'green' if change > 0 else 'red'
                ax.annotate(f'{change:+.1f}%', 
                           xy=(i, max(pre_val, post_val) + 5),
                           ha='center', va='bottom',
                           color=color, fontweight='bold')
        
        plt.tight_layout()
        self.figures.append(('throughput_comparison', fig))
        
    def create_dns_performance_chart(self):
        """Create DNS performance comparison chart"""
        if not ('dns' in self.pre_results and 'dns' in self.post_results):
            return
            
        pre = self.pre_results['dns']
        post = self.post_results['dns']
        
        fig, ax = plt.subplots(figsize=(10, 6))
        
        # Extract DNS performance metrics
        metrics = ['Min Response', 'Avg Response', 'Max Response']
        
        pre_values = []
        post_values = []
        
        # Handle different JSON formats
        if 'summary' in pre:
            pre_values = [
                pre['summary'].get('min_response_time_ms', 0),
                pre['summary'].get('avg_response_time_ms', 0),
                pre['summary'].get('max_response_time_ms', 0)
            ]
        else:
            pre_values = [
                pre.get('min_latency_ms', 0),
                pre.get('avg_latency_ms', 0),
                pre.get('max_latency_ms', 0)
            ]
            
        if 'summary' in post:
            post_values = [
                post['summary'].get('min_response_time_ms', 0),
                post['summary'].get('avg_response_time_ms', 0),
                post['summary'].get('max_response_time_ms', 0)
            ]
        else:
            post_values = [
                post.get('min_latency_ms', 0),
                post.get('avg_latency_ms', 0),
                post.get('max_latency_ms', 0)
            ]
        
        x = np.arange(len(metrics))
        width = 0.35
        
        bars1 = ax.bar(x - width/2, pre_values, width, label='Pre', color='#9b59b6')
        bars2 = ax.bar(x + width/2, post_values, width, label='Post', color='#f39c12')
        
        ax.set_xlabel('Metric')
        ax.set_ylabel('Response Time (ms)')
        ax.set_title(f"DNS Performance - Server: {pre.get('dns_server', 'Unknown')}")
        ax.set_xticks(x)
        ax.set_xticklabels(metrics)
        ax.legend()
        
        # Add value labels
        self._add_value_labels(ax, bars1)
        self._add_value_labels(ax, bars2)
        
        plt.tight_layout()
        self.figures.append(('dns_performance', fig))
        
    def create_summary_dashboard(self):
        """Create a summary dashboard with key metrics"""
        fig = plt.figure(figsize=(14, 10))
        
        # Calculate improvements/degradations
        metrics = self._calculate_all_changes()
        
        # Create subplots
        gs = fig.add_gridspec(3, 3, hspace=0.3, wspace=0.3)
        
        # 1. Overall Performance Change
        ax1 = fig.add_subplot(gs[0, :])
        self._create_performance_summary(ax1, metrics)
        
        # 2. Latency metrics
        ax2 = fig.add_subplot(gs[1, 0])
        self._create_latency_gauge(ax2, metrics)
        
        # 3. Throughput metrics
        ax3 = fig.add_subplot(gs[1, 1])
        self._create_throughput_gauge(ax3, metrics)
        
        # 4. DNS metrics
        ax4 = fig.add_subplot(gs[1, 2])
        self._create_dns_gauge(ax4, metrics)
        
        # 5. Detailed comparison table
        ax5 = fig.add_subplot(gs[2, :])
        self._create_comparison_table(ax5, metrics)
        
        plt.suptitle('Performance Test Summary Dashboard', fontsize=16, fontweight='bold')
        self.figures.append(('summary_dashboard', fig))
        
    def _calculate_all_changes(self):
        """Calculate all performance changes"""
        metrics = {}
        
        # Ping metrics
        if 'ping' in self.pre_results and 'ping' in self.post_results:
            pre = self.pre_results['ping']
            post = self.post_results['ping']
            metrics['ping_latency_change'] = self._calc_percent_change(
                pre.get('rtt_avg_ms', 0),
                post.get('rtt_avg_ms', 0)
            )
            metrics['packet_loss_diff'] = post.get('packet_loss_percent', 0) - pre.get('packet_loss_percent', 0)
            
        # Throughput metrics
        throughput_changes = []
        for test in ['iperf', 'wget', 'curl', 'scp', 'rsync']:
            if test in self.pre_results and test in self.post_results:
                pre_speed = self.pre_results[test].get('speed_mbps', 0) or self.pre_results[test].get('avg_mbps', 0)
                post_speed = self.post_results[test].get('speed_mbps', 0) or self.post_results[test].get('avg_mbps', 0)
                if pre_speed > 0:
                    change = self._calc_percent_change(pre_speed, post_speed)
                    throughput_changes.append(change)
                    metrics[f'{test}_change'] = change
                    
        if throughput_changes:
            metrics['avg_throughput_change'] = sum(throughput_changes) / len(throughput_changes)
            
        # DNS metrics
        if 'dns' in self.pre_results and 'dns' in self.post_results:
            pre = self.pre_results['dns']
            post = self.post_results['dns']
            
            if 'summary' in pre and 'summary' in post:
                pre_time = pre['summary'].get('avg_response_time_ms', 0)
                post_time = post['summary'].get('avg_response_time_ms', 0)
            else:
                pre_time = pre.get('avg_latency_ms', 0)
                post_time = post.get('avg_latency_ms', 0)
                
            metrics['dns_response_change'] = self._calc_percent_change(pre_time, post_time)
            
        return metrics
    
    def _calc_percent_change(self, old_val, new_val):
        """Calculate percentage change"""
        if old_val == 0:
            return 0 if new_val == 0 else 100
        return ((new_val - old_val) / old_val) * 100
    
    def _create_performance_summary(self, ax, metrics):
        """Create overall performance summary"""
        ax.axis('off')
        
        # Count improvements vs degradations
        improvements = sum(1 for k, v in metrics.items() if 'change' in k and v > 5)
        degradations = sum(1 for k, v in metrics.items() if 'change' in k and v < -5)
        neutral = sum(1 for k, v in metrics.items() if 'change' in k and -5 <= v <= 5)
        
        # Create summary text
        summary_text = f"Performance Test Results Summary\n\n"
        summary_text += f"✓ Improvements: {improvements}\n"
        summary_text += f"✗ Degradations: {degradations}\n"
        summary_text += f"= No Change: {neutral}\n\n"
        
        if 'avg_throughput_change' in metrics:
            summary_text += f"Average Throughput Change: {metrics['avg_throughput_change']:+.1f}%\n"
        if 'ping_latency_change' in metrics:
            summary_text += f"Ping Latency Change: {metrics['ping_latency_change']:+.1f}%\n"
        if 'dns_response_change' in metrics:
            summary_text += f"DNS Response Change: {metrics['dns_response_change']:+.1f}%"
            
        ax.text(0.5, 0.5, summary_text, ha='center', va='center', 
                fontsize=12, transform=ax.transAxes,
                bbox=dict(boxstyle='round,pad=0.5', facecolor='lightgray', alpha=0.5))
    
    def _create_latency_gauge(self, ax, metrics):
        """Create latency change gauge"""
        if 'ping_latency_change' not in metrics:
            ax.axis('off')
            ax.text(0.5, 0.5, 'No Latency Data', ha='center', va='center')
            return
            
        change = metrics['ping_latency_change']
        self._create_gauge(ax, change, 'Latency Change', inverse=True)
        
    def _create_throughput_gauge(self, ax, metrics):
        """Create throughput change gauge"""
        if 'avg_throughput_change' not in metrics:
            ax.axis('off')
            ax.text(0.5, 0.5, 'No Throughput Data', ha='center', va='center')
            return
            
        change = metrics['avg_throughput_change']
        self._create_gauge(ax, change, 'Throughput Change')
        
    def _create_dns_gauge(self, ax, metrics):
        """Create DNS performance gauge"""
        if 'dns_response_change' not in metrics:
            ax.axis('off')
            ax.text(0.5, 0.5, 'No DNS Data', ha='center', va='center')
            return
            
        change = metrics['dns_response_change']
        self._create_gauge(ax, change, 'DNS Response Change', inverse=True)
        
    def _create_gauge(self, ax, value, title, inverse=False):
        """Create a gauge chart"""
        ax.axis('off')
        
        # Determine color based on value and direction
        if inverse:  # For metrics where lower is better
            if value < -5:
                color = 'green'
            elif value > 5:
                color = 'red'
            else:
                color = 'yellow'
        else:  # For metrics where higher is better
            if value > 5:
                color = 'green'
            elif value < -5:
                color = 'red'
            else:
                color = 'yellow'
                
        # Create gauge
        theta = np.linspace(np.pi, 0, 100)
        r_inner = 0.6
        r_outer = 0.8
        
        x_inner = r_inner * np.cos(theta)
        y_inner = r_inner * np.sin(theta)
        x_outer = r_outer * np.cos(theta)
        y_outer = r_outer * np.sin(theta)
        
        # Background arc
        ax.fill_between(x_outer, y_outer, y_inner, color='lightgray', alpha=0.3)
        
        # Value arc (limited to -100% to +100%)
        value_clamped = max(-100, min(100, value))
        value_angle = np.pi - (value_clamped + 100) / 200 * np.pi
        theta_value = np.linspace(np.pi, value_angle, 50)
        
        x_value_inner = r_inner * np.cos(theta_value)
        y_value_inner = r_inner * np.sin(theta_value)
        x_value_outer = r_outer * np.cos(theta_value)
        y_value_outer = r_outer * np.sin(theta_value)
        
        ax.fill_between(x_value_outer, y_value_outer, y_value_inner, color=color, alpha=0.7)
        
        # Add text
        ax.text(0, 0, f'{value:+.1f}%', ha='center', va='center', fontsize=16, fontweight='bold')
        ax.text(0, -0.4, title, ha='center', va='center', fontsize=10)
        
        ax.set_xlim(-1, 1)
        ax.set_ylim(-0.5, 1)
        
    def _create_comparison_table(self, ax, metrics):
        """Create detailed comparison table"""
        ax.axis('off')
        
        # Prepare table data
        rows = []
        for key, value in sorted(metrics.items()):
            if 'change' in key or 'diff' in key:
                test_name = key.replace('_change', '').replace('_diff', '').replace('_', ' ').title()
                if 'diff' in key:
                    rows.append([test_name, f"{value:+.2f}"])
                else:
                    rows.append([test_name, f"{value:+.1f}%"])
                    
        if not rows:
            ax.text(0.5, 0.5, 'No comparison data available', ha='center', va='center')
            return
            
        # Create table
        table = ax.table(cellText=rows, colLabels=['Metric', 'Change'],
                        cellLoc='center', loc='center',
                        colWidths=[0.7, 0.3])
        table.auto_set_font_size(False)
        table.set_fontsize(10)
        table.scale(1, 1.5)
        
        # Color cells based on values
        for i, row in enumerate(rows):
            if '%' in row[1]:
                value = float(row[1].replace('%', '').replace('+', ''))
                if value > 5:
                    table[(i+1, 1)].set_facecolor('#90EE90')
                elif value < -5:
                    table[(i+1, 1)].set_facecolor('#FFB6C1')
    
    def _add_value_labels(self, ax, bars):
        """Add value labels on top of bars"""
        for bar in bars:
            height = bar.get_height()
            if height > 0:
                ax.annotate(f'{height:.1f}',
                           xy=(bar.get_x() + bar.get_width() / 2, height),
                           xytext=(0, 3),
                           textcoords="offset points",
                           ha='center', va='bottom',
                           fontsize=9)
    
    def save_all_figures(self, output_dir=None):
        """Save all generated figures"""
        if output_dir is None:
            output_dir = os.path.join(self.results_dir, 'visualizations')
            
        os.makedirs(output_dir, exist_ok=True)
        
        for name, fig in self.figures:
            output_path = os.path.join(output_dir, f'{name}.png')
            fig.savefig(output_path, dpi=300, bbox_inches='tight')
            print(f"Saved: {output_path}")
            
    def show_all_figures(self):
        """Display all figures"""
        plt.show()

def main():
    parser = argparse.ArgumentParser(description='Visualize performance test results')
    parser.add_argument('results_dir', help='Directory containing test results')
    parser.add_argument('-o', '--output', help='Output directory for visualizations')
    parser.add_argument('-s', '--show', action='store_true', help='Display figures')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.results_dir):
        print(f"Error: Results directory not found: {args.results_dir}")
        sys.exit(1)
        
    visualizer = TestResultsVisualizer(args.results_dir)
    visualizer.load_json_results()
    
    # Create all visualizations
    visualizer.create_ping_comparison()
    visualizer.create_throughput_comparison()
    visualizer.create_dns_performance_chart()
    visualizer.create_summary_dashboard()
    
    # Save figures
    visualizer.save_all_figures(args.output)
    
    # Show figures if requested
    if args.show:
        visualizer.show_all_figures()
        
    print("\nVisualization complete!")

if __name__ == "__main__":
    main()