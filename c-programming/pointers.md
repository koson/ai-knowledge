หัวข้อ: Pointer พื้นฐานในภาษา C

- pointer คือ ตัวแปรที่เก็บ address ของข้อมูล
- ประกาศ pointer เช่น `int *p;`
- `&x` ใช้หา address ของตัวแปร `x`
- `*p` ใช้ dereference เพื่อเข้าถึงค่าที่ address นั้นชี้อยู่
- ถ้า `p = &x` แล้ว `*p` คือค่าของ `x`
- ต้องกำหนดค่า pointer ให้ชี้ไปยัง address ที่ถูกต้องก่อน dereference
- การ dereference pointer ที่เป็น `NULL` หรือ address ผิด จะทำให้โปรแกรมผิดพลาดได้
- pointer arithmetic จะเลื่อนตามขนาดของชนิดข้อมูลที่ pointer ชี้อยู่
- ชื่อ array ในหลายบริบทจะ decay เป็น pointer ไปยังสมาชิกตัวแรก
- ควรตรวจสอบ `NULL` ก่อนใช้งาน pointer ที่อาจยังไม่ถูกกำหนด