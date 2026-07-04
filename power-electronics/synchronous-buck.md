หัวข้อ: Synchronous Buck Converter 

- ใช้ MOSFET high-side และ low-side แทน diode เพื่อลด conduction loss
- high-side เปิด → กระแสไหลผ่าน inductor ไปยังโหลด
- high-side ปิด → inductor freewheel ผ่าน MOSFET low-side
- duty cycle = Vout / Vin (ideal)
- ต้องมี dead-time เพื่อป้องกัน shoot-through
- inductor current ไหลต่อเนื่องใน CCM