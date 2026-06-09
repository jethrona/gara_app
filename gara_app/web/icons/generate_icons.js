const fs = require('fs');
const { createCanvas } = require('canvas');

function createIcon(size, outputPath) {
  const canvas = createCanvas(size, size);
  const ctx = canvas.getContext('2d');

  // Green background
  ctx.fillStyle = '#10b981';
  ctx.beginPath();
  ctx.arc(size / 2, size / 2, size / 2, 0, Math.PI * 2);
  ctx.fill();

  // White "G" letter
  ctx.fillStyle = '#ffffff';
  ctx.font = `bold ${size * 0.55}px Arial, sans-serif`;
  ctx.textAlign = 'center';
  ctx.textBaseline = 'middle';
  ctx.fillText('G', size / 2, size / 2 + size * 0.03);

  const buffer = canvas.toBuffer('image/png');
  fs.writeFileSync(outputPath, buffer);
  console.log(`Created ${outputPath} (${size}x${size})`);
}

// Create icons directory if it doesn't exist
const dir = __dirname;
[192, 512].forEach(size => {
  createIcon(size, `${dir}/Icon-${size}.png`);
  createIcon(size, `${dir}/Icon-maskable-${size}.png`);
});

// Also create favicon (32x32)
createIcon(32, `${dir}/../favicon.png`);
