from docx import Document
from docx.oxml.ns import qn


doc = Document("docs/บทที่ 3_แก้ไขแล้ว.docx")
body = doc._body._element
table_index = 0
para_index = 0
print("body children", len(body))
for child_index, child in enumerate(body):
    tag = child.tag.split("}")[-1]
    if tag == "p":
        text = "".join(t.text or "" for t in child.iter(qn("w:t"))).strip()
        if 160 <= para_index <= 205 or "ตารางที่ 3.1" in text or "3.3.3" in text:
            print(child_index, "P", para_index, text[:180])
        para_index += 1
    elif tag == "tbl":
        table_index += 1
        print(child_index, "T", table_index)
