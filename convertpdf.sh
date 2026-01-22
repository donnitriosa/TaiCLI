#!/bin/bash

# 1. Cek argumen input (Hanya File)
if [ -z "$1" ]; then
    echo "❌ Error: Harap masukkan nama file log."
    echo "Usage: $0 <path/to/file.log>"
    exit 1
fi

INPUT_FILE="$1"

# 2. Cek keberadaan file
if [ ! -f "$INPUT_FILE" ]; then
    echo "❌ Error: File '$INPUT_FILE' tidak ditemukan."
    exit 1
fi

# 3. Input Nama Secara Interaktif
echo "------------------------------------------------"
read -p "Masukkan Nama Lengkap untuk Laporan: " USER_NAME
echo "------------------------------------------------"

if [ -z "$USER_NAME" ]; then
    USER_NAME="Unknown User"
fi

# 4. Setup Nama & Folder Output
BASENAME=$(basename -- "$INPUT_FILE")
FILENAME_NO_EXT="${BASENAME%.*}"
OUTPUT_DIR="pdf"
mkdir -p "$OUTPUT_DIR"
OUTPUT_HTML="${FILENAME_NO_EXT}_temp.html"
OUTPUT_PDF="${OUTPUT_DIR}/${FILENAME_NO_EXT}.pdf"

# Tentukan lokasi Chrome
if [[ "$OSTYPE" == "darwin"* ]]; then
    CHROME_PATH="/Applications/Google Chrome.app/Contents/MacOS/Google Chrome"
else
    CHROME_PATH="google-chrome"
fi

# 5. Extract Bulan dan Tahun dari Log
FIRST_DATE=$(grep -oE '[0-9]{4}-[0-9]{2}-[0-9]{2}' "$INPUT_FILE" | head -1)

if [ -n "$FIRST_DATE" ]; then
    if [[ "$OSTYPE" == "darwin"* ]]; then
        REPORT_PERIOD=$(date -j -f "%Y-%m-%d" "$FIRST_DATE" "+%B %Y")
    else
        REPORT_PERIOD=$(date -d "$FIRST_DATE" "+%B %Y")
    fi
else
    REPORT_PERIOD="Unknown Date"
fi

# 6. Buat Header HTML (Desain Hybrid: Warna Hijau + Struktur Modern)
echo "Processing $INPUT_FILE for $USER_NAME..."
cat <<EOF > "$OUTPUT_HTML"
<!DOCTYPE html>
<html>
<head>
<style>
    @page { margin: 15mm; size: A4; }
    body { 
        font-family: 'Helvetica Neue', Helvetica, Arial, sans-serif; 
        font-size: 12px; 
        color: #333;
        -webkit-print-color-adjust: exact; 
    }
    
    /* Header Styles */
    .header-container { 
        text-align: center; 
        margin-bottom: 35px; 
        padding-bottom: 15px;
        border-bottom: 3px solid #009879; /* Green Teal Border */
    }
    h1 { 
        margin: 0; 
        font-size: 28px; 
        color: #065f46; /* Dark Green Title for Contrast */
        font-weight: 700;
        letter-spacing: 0.5px;
    }
    h3 { 
        margin: 8px 0 0 0; 
        font-size: 14px; 
        color: #64748B; 
        font-weight: 500; 
        text-transform: uppercase;
        letter-spacing: 1px;
    }

    /* Table Styles (Modern Structure) */
    table { 
        width: 100%; 
        border-collapse: collapse; 
        margin-top: 10px; 
        box-shadow: 0 4px 6px -1px rgba(0, 0, 0, 0.1); /* Soft Shadow */
        border-radius: 8px; /* Rounded Corners */
        overflow: hidden; 
    }
    
    thead {
        background-color: #009879; /* Green Teal Header */
    }

    th { 
        color: white; 
        padding: 14px 15px; 
        text-align: left; 
        font-weight: 600;
        text-transform: uppercase;
        font-size: 11px;
        letter-spacing: 0.5px;
    }
    
    td { 
        padding: 12px 15px; 
        border-bottom: 1px solid #E2E8F0; 
        color: #334155;
    }
    
    tr:nth-of-type(even) { 
        background-color: #F0FDF4; /* Very Light Mint Green for Zebra */
    }
    
    tr:last-of-type td {
        border-bottom: 3px solid #009879; /* Green bottom line */
    }

    /* Badge Style for Status (Green Variant) */
    .status-badge {
        background-color: #DCFCE7; /* Pale Green Background */
        color: #166534; /* Dark Green Text */
        padding: 4px 12px;
        border-radius: 9999px; /* Pill Shape */
        font-weight: 700;
        font-size: 10px;
        display: inline-block;
        border: 1px solid #86EFAC;
    }
</style>
</head>
<body>
    <div class="header-container">
        <h1>Activity Log Report</h1>
        <h3>$USER_NAME &nbsp;&bull;&nbsp; $REPORT_PERIOD</h3>
    </div>
    <table>
        <thead>
            <tr>
                <th style="width: 45%">Activity Title</th>
                <th style="width: 15%">Date</th>
                <th style="width: 15%">Start Time</th>
                <th style="width: 10%">Duration</th>
                <th style="width: 15%; text-align: center;">Status</th>
            </tr>
        </thead>
        <tbody>
EOF

# 7. Proses Log
sed -E 's/\+\]//g' "$INPUT_FILE" | awk '
{
    gsub(/^[ \t]+|[ \t]+$/, ""); 
    if ($0 == "") next;
    if (buffer == "") { buffer = $0; } else { buffer = buffer " " $0; }
    if ($0 !~ /\|$/) { print buffer; buffer = ""; }
}' | awk -F'|' '
{
    for(i=1; i<=NF; i++) gsub(/^[ \t]+|[ \t]+$/, "", $i);
    print "<tr>";
    print "<td>" $1 "</td>";
    print "<td>" $2 "</td>";
    print "<td>" $(NF-1) "</td>";
    print "<td>" $NF " Mins</td>";
    print "<td style=\"text-align:center;\"><span class=\"status-badge\">Done</span></td>";
    print "</tr>";
}' >> "$OUTPUT_HTML"

echo "        </tbody>
    </table>
</body>
</html>" >> "$OUTPUT_HTML"

# 8. Convert ke PDF
echo "Generating PDF..."
if [ -f "$CHROME_PATH" ] || command -v "$CHROME_PATH" &> /dev/null; then
    "$CHROME_PATH" --headless --disable-gpu --print-to-pdf="$OUTPUT_PDF" "$OUTPUT_HTML" > /dev/null 2>&1
    
    rm "$OUTPUT_HTML"
    echo "✅ Selesai! File tersimpan di: $OUTPUT_PDF"
else
    echo "❌ ERROR: Google Chrome tidak ditemukan."
fi