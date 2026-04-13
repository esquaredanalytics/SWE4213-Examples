const btn = document.getElementById("newImageBtn");
const img = document.getElementById("photo");

// TODO 4: Create a reference to the imageCountLabel

const label = document.getElementById("imageCountLabel");
let imageCount = 0; 

btn.addEventListener("click", () => {
  img.src = `https://picsum.photos/600/400?random=${Date.now()}`;

  // TODO 5: Update the image count label to the number of images that have been shown. 
  imageCount++;
  label.textContent = `Number of Images Shown: ${imageCount}`;
});
