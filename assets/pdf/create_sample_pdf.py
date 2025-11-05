#!/usr/bin/env python3
"""
用于创建示例PDF文件的脚本
运行: python3 create_sample_pdf.py
"""

try:
    from reportlab.lib.pagesizes import letter
    from reportlab.pdfgen import canvas
    
    def create_sample_pdf():
        """创建一个示例PDF文件"""
        pdf_path = 'sample.pdf'
        c = canvas.Canvas(pdf_path, pagesize=letter)
        
        # 添加标题
        c.setFont("Helvetica-Bold", 24)
        c.drawString(100, 750, "示例PDF文档")
        
        # 添加内容
        c.setFont("Helvetica", 12)
        content = [
            "这是一个示例PDF文件，用于Flutter应用测试。",
            "",
            "这个PDF包含：",
            "1. 基本信息展示",
            "2. PDF预览功能",
            "3. 针对平板设备优化",
            "",
            "您可以替换此文件为您自己的PDF文件。"
        ]
        
        y_position = 700
        for line in content:
            c.drawString(100, y_position, line)
            y_position -= 20
        
        # 添加页码
        for page_num in range(1, 11):
            c.drawString(100, 50, f"第 {page_num} 页")
            if page_num < 10:
                c.showPage()
        
        c.save()
        print(f"PDF文件已创建: {pdf_path}")
    
    if __name__ == "__main__":
        create_sample_pdf()
        
except ImportError:
    print("请先安装reportlab: pip3 install reportlab")
    print("或者手动创建一个名为 sample.pdf 的文件放在此目录下")

