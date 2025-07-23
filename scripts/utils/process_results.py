#!/usr/bin/env python3

"""
Process and compare performance test results
Parses JSON and text output from various test scripts
"""

import json
import csv
import os
import sys
import glob
import re
from datetime import datetime
from collections import defaultdict
import argparse

class TestResultsProcessor:
    def __init__(self, results_dir):
        self.results_dir = results_dir
        self.pre_results = defaultdict(dict)
        self.post_results = defaultdict(dict)
        
    def find_result_files(self):
        """Find all result files in the directory"""
        json_files = glob.glob(os.path.join(self.results_dir, "*.json"))
        txt_files = glob.glob(os.path.join(self.results_dir, "*.txt"))
        
        files = {
            'pre': {'json': [], 'txt': []},
            'post': {'json': [], 'txt': []}
        }
        
        for f in json_files:
            if 'pre_' in os.path.basename(f):
                files['pre']['json'].append(f)
            elif 'post_' in os.path.basename(f):
                files['post']['json'].append(f)
                
        for f in txt_files:
            if 'pre_' in os.path.basename(f):
                files['pre']['txt'].append(f)
            elif 'post_' in os.path.basename(f):
                files['post']['txt'].append(f)
                
        return files
    
    def parse_ping_results(self, json_file):
        """Parse ping test JSON results"""
        with open(json_file, 'r') as f:
            data = json.load(f)
            
        return {
            'avg_rtt': data.get('rtt_avg_ms', 0),
            'min_rtt': data.get('rtt_min_ms', 0),
            'max_rtt': data.get('rtt_max_ms', 0),
            'packet_loss': data.get('packet_loss_percent', 0),
            'destination': data.get('destination', 'unknown')
        }
    
    def parse_iperf_results(self, json_file):
        """Parse iperf3 JSON results"""
        with open(json_file, 'r') as f:
            data = json.load(f)
            
        if 'end' in data:
            # Standard iperf3 JSON format
            sender = data['end']['sum_sent']['bits_per_second'] / 1e6  # Convert to Mbps
            receiver = data['end']['sum_received']['bits_per_second'] / 1e6
            
            return {
                'sender_mbps': sender,
                'receiver_mbps': receiver,
                'avg_mbps': (sender + receiver) / 2
            }
        else:
            # Custom format from our script
            return {
                'avg_mbps': data.get('speed_mbps', 0)
            }
    
    def parse_dns_results(self, json_file):
        """Parse DNS test JSON results"""
        with open(json_file, 'r') as f:
            data = json.load(f)
            
        if 'summary' in data:
            return {
                'avg_response_time': data['summary']['avg_response_time_ms'],
                'min_response_time': data['summary']['min_response_time_ms'],
                'max_response_time': data['summary']['max_response_time_ms'],
                'success_rate': data['summary']['success_rate'],
                'dns_server': data.get('dns_server', 'unknown')
            }
        else:
            # dnsperf format
            return {
                'avg_response_time': data.get('avg_latency_ms', 0),
                'min_response_time': data.get('min_latency_ms', 0),
                'max_response_time': data.get('max_latency_ms', 0),
                'queries_completed': data.get('queries_completed', 0),
                'dns_server': data.get('dns_server', 'unknown')
            }
    
    def parse_transfer_results(self, json_file):
        """Parse data transfer test JSON results"""
        with open(json_file, 'r') as f:
            data = json.load(f)
            
        return {
            'test_type': data.get('test_type', 'unknown'),
            'speed_mbps': data.get('speed_mbps', 0),
            'file_size_mb': data.get('file_size_bytes', 0) / 1048576,
            'duration_seconds': data.get('duration_seconds', 0),
            'status': data.get('status', 'unknown')
        }
    
    def parse_yabs_results(self, txt_file):
        """Parse YABS benchmark text results"""
        results = {}
        
        with open(txt_file, 'r') as f:
            content = f.read()
            
        # Extract CPU info
        cpu_match = re.search(r'CPU cores\s+:\s+(\d+)\s+@\s+([\d.]+\s+\w+)', content)
        if cpu_match:
            results['cpu_cores'] = int(cpu_match.group(1))
            results['cpu_freq'] = cpu_match.group(2)
            
        # Extract Geekbench scores
        gb_single = re.search(r'Single-Core Score\s+:\s+(\d+)', content)
        gb_multi = re.search(r'Multi-Core Score\s+:\s+(\d+)', content)
        if gb_single:
            results['geekbench_single'] = int(gb_single.group(1))
        if gb_multi:
            results['geekbench_multi'] = int(gb_multi.group(1))
            
        # Extract disk speeds (fio results)
        fio_results = re.findall(r'(\d+k?)\s+:\s+([\d.]+)\s+MB/s\s+\(([\d.]+)\s+IOPS\)', content)
        for block_size, speed, iops in fio_results:
            key = f'disk_{block_size}_mbps'
            results[key] = float(speed)
            results[f'disk_{block_size}_iops'] = float(iops)
            
        return results
    
    def load_all_results(self):
        """Load and parse all result files"""
        files = self.find_result_files()
        
        # Process pre-test results
        for json_file in files['pre']['json']:
            filename = os.path.basename(json_file)
            
            if 'ping' in filename:
                self.pre_results['ping'] = self.parse_ping_results(json_file)
            elif 'iperf' in filename:
                self.pre_results['iperf'] = self.parse_iperf_results(json_file)
            elif 'dns' in filename:
                self.pre_results['dns'] = self.parse_dns_results(json_file)
            elif any(t in filename for t in ['scp', 'rsync', 'wget', 'curl']):
                transfer_data = self.parse_transfer_results(json_file)
                self.pre_results[f'transfer_{transfer_data["test_type"]}'] = transfer_data
                
        # Process post-test results
        for json_file in files['post']['json']:
            filename = os.path.basename(json_file)
            
            if 'ping' in filename:
                self.post_results['ping'] = self.parse_ping_results(json_file)
            elif 'iperf' in filename:
                self.post_results['iperf'] = self.parse_iperf_results(json_file)
            elif 'dns' in filename:
                self.post_results['dns'] = self.parse_dns_results(json_file)
            elif any(t in filename for t in ['scp', 'rsync', 'wget', 'curl']):
                transfer_data = self.parse_transfer_results(json_file)
                self.post_results[f'transfer_{transfer_data["test_type"]}'] = transfer_data
                
        # Process YABS results
        for txt_file in files['pre']['txt']:
            if 'yabs' in os.path.basename(txt_file):
                self.pre_results['yabs'] = self.parse_yabs_results(txt_file)
                
        for txt_file in files['post']['txt']:
            if 'yabs' in os.path.basename(txt_file):
                self.post_results['yabs'] = self.parse_yabs_results(txt_file)
    
    def calculate_changes(self):
        """Calculate percentage changes between pre and post results"""
        changes = {}
        
        # Compare ping results
        if 'ping' in self.pre_results and 'ping' in self.post_results:
            pre = self.pre_results['ping']
            post = self.post_results['ping']
            
            changes['ping'] = {
                'avg_rtt_change': self._calc_percent_change(pre['avg_rtt'], post['avg_rtt']),
                'packet_loss_change': post['packet_loss'] - pre['packet_loss']
            }
            
        # Compare iperf results
        if 'iperf' in self.pre_results and 'iperf' in self.post_results:
            pre = self.pre_results['iperf']
            post = self.post_results['iperf']
            
            changes['iperf'] = {
                'throughput_change': self._calc_percent_change(
                    pre.get('avg_mbps', 0), 
                    post.get('avg_mbps', 0)
                )
            }
            
        # Compare DNS results
        if 'dns' in self.pre_results and 'dns' in self.post_results:
            pre = self.pre_results['dns']
            post = self.post_results['dns']
            
            changes['dns'] = {
                'avg_response_change': self._calc_percent_change(
                    pre['avg_response_time'], 
                    post['avg_response_time']
                )
            }
            
        # Compare transfer speeds
        for transfer_type in ['scp', 'rsync', 'wget', 'curl']:
            pre_key = f'transfer_{transfer_type}'
            post_key = f'transfer_{transfer_type}'
            
            if pre_key in self.pre_results and post_key in self.post_results:
                pre = self.pre_results[pre_key]
                post = self.post_results[post_key]
                
                changes[pre_key] = {
                    'speed_change': self._calc_percent_change(
                        pre['speed_mbps'], 
                        post['speed_mbps']
                    )
                }
                
        return changes
    
    def _calc_percent_change(self, old_val, new_val):
        """Calculate percentage change"""
        if old_val == 0:
            return 0 if new_val == 0 else 100
        return ((new_val - old_val) / old_val) * 100
    
    def export_to_csv(self, output_file):
        """Export results to CSV format"""
        rows = []
        
        # Prepare header
        headers = ['Test Type', 'Metric', 'Pre-Test Value', 'Post-Test Value', 'Change %']
        
        # Add ping results
        if 'ping' in self.pre_results or 'ping' in self.post_results:
            pre = self.pre_results.get('ping', {})
            post = self.post_results.get('ping', {})
            
            rows.append([
                'Ping',
                'Average RTT (ms)',
                pre.get('avg_rtt', 'N/A'),
                post.get('avg_rtt', 'N/A'),
                self._format_percent(self._calc_percent_change(
                    pre.get('avg_rtt', 0),
                    post.get('avg_rtt', 0)
                )) if pre and post else 'N/A'
            ])
            
            rows.append([
                'Ping',
                'Packet Loss (%)',
                pre.get('packet_loss', 'N/A'),
                post.get('packet_loss', 'N/A'),
                f"{post.get('packet_loss', 0) - pre.get('packet_loss', 0):.1f}" if pre and post else 'N/A'
            ])
            
        # Add iperf results
        if 'iperf' in self.pre_results or 'iperf' in self.post_results:
            pre = self.pre_results.get('iperf', {})
            post = self.post_results.get('iperf', {})
            
            rows.append([
                'iPerf3',
                'Throughput (Mbps)',
                f"{pre.get('avg_mbps', 0):.2f}" if pre else 'N/A',
                f"{post.get('avg_mbps', 0):.2f}" if post else 'N/A',
                self._format_percent(self._calc_percent_change(
                    pre.get('avg_mbps', 0),
                    post.get('avg_mbps', 0)
                )) if pre and post else 'N/A'
            ])
            
        # Add DNS results
        if 'dns' in self.pre_results or 'dns' in self.post_results:
            pre = self.pre_results.get('dns', {})
            post = self.post_results.get('dns', {})
            
            rows.append([
                'DNS',
                'Avg Response Time (ms)',
                f"{pre.get('avg_response_time', 0):.2f}" if pre else 'N/A',
                f"{post.get('avg_response_time', 0):.2f}" if post else 'N/A',
                self._format_percent(self._calc_percent_change(
                    pre.get('avg_response_time', 0),
                    post.get('avg_response_time', 0)
                )) if pre and post else 'N/A'
            ])
            
        # Add transfer results
        for transfer_type in ['wget', 'curl', 'scp', 'rsync']:
            key = f'transfer_{transfer_type}'
            if key in self.pre_results or key in self.post_results:
                pre = self.pre_results.get(key, {})
                post = self.post_results.get(key, {})
                
                rows.append([
                    transfer_type.upper(),
                    'Transfer Speed (MB/s)',
                    f"{pre.get('speed_mbps', 0):.2f}" if pre else 'N/A',
                    f"{post.get('speed_mbps', 0):.2f}" if post else 'N/A',
                    self._format_percent(self._calc_percent_change(
                        pre.get('speed_mbps', 0),
                        post.get('speed_mbps', 0)
                    )) if pre and post else 'N/A'
                ])
        
        # Write to CSV
        with open(output_file, 'w', newline='') as csvfile:
            writer = csv.writer(csvfile)
            writer.writerow(headers)
            writer.writerows(rows)
            
        print(f"Results exported to: {output_file}")
    
    def _format_percent(self, value):
        """Format percentage value"""
        if value > 0:
            return f"+{value:.1f}%"
        else:
            return f"{value:.1f}%"
    
    def generate_report(self):
        """Generate a comparison report"""
        changes = self.calculate_changes()
        
        print("\n" + "="*60)
        print("Performance Test Results Comparison")
        print("="*60)
        
        # Network Performance
        print("\n### Network Performance ###")
        if 'ping' in changes:
            ping_change = changes['ping']
            print(f"Ping RTT Change: {self._format_percent(ping_change['avg_rtt_change'])}")
            print(f"Packet Loss Change: {ping_change['packet_loss_change']:.1f}%")
            
        if 'iperf' in changes:
            iperf_change = changes['iperf']
            print(f"Throughput Change: {self._format_percent(iperf_change['throughput_change'])}")
            
        # DNS Performance
        print("\n### DNS Performance ###")
        if 'dns' in changes:
            dns_change = changes['dns']
            print(f"Response Time Change: {self._format_percent(dns_change['avg_response_change'])}")
            
        # Data Transfer Performance
        print("\n### Data Transfer Performance ###")
        for transfer_type in ['wget', 'curl', 'scp', 'rsync']:
            key = f'transfer_{transfer_type}'
            if key in changes:
                speed_change = changes[key]['speed_change']
                print(f"{transfer_type.upper()} Speed Change: {self._format_percent(speed_change)}")
                
        # Summary
        print("\n### Summary ###")
        improvements = []
        degradations = []
        
        for test_type, metrics in changes.items():
            for metric, value in metrics.items():
                if 'change' in metric and isinstance(value, (int, float)):
                    if value > 5:  # More than 5% improvement
                        improvements.append(f"{test_type}: {self._format_percent(value)}")
                    elif value < -5:  # More than 5% degradation
                        degradations.append(f"{test_type}: {self._format_percent(value)}")
                        
        if improvements:
            print("\nImprovements:")
            for imp in improvements:
                print(f"  ✓ {imp}")
                
        if degradations:
            print("\nDegradations:")
            for deg in degradations:
                print(f"  ✗ {deg}")
                
        if not improvements and not degradations:
            print("\nNo significant changes detected (±5% threshold)")

def main():
    parser = argparse.ArgumentParser(description='Process and compare performance test results')
    parser.add_argument('results_dir', help='Directory containing test results')
    parser.add_argument('-o', '--output', help='Output CSV file', default='comparison_results.csv')
    parser.add_argument('-r', '--report', action='store_true', help='Generate comparison report')
    
    args = parser.parse_args()
    
    if not os.path.exists(args.results_dir):
        print(f"Error: Results directory not found: {args.results_dir}")
        sys.exit(1)
        
    processor = TestResultsProcessor(args.results_dir)
    processor.load_all_results()
    
    if args.report:
        processor.generate_report()
        
    processor.export_to_csv(args.output)
    
    print(f"\nProcessing complete. CSV output: {args.output}")

if __name__ == "__main__":
    main()