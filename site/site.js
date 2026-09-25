const review = document.querySelector('#draft-review');
const trigger = document.querySelector('#review-demo');
if (review && trigger) {
  trigger.addEventListener('click', () => review.showModal());
  review.addEventListener('click', event => { if (event.target === review) { const rect = review.getBoundingClientRect(); if (event.clientX < rect.left || event.clientX > rect.right || event.clientY < rect.top || event.clientY > rect.bottom) review.close(); } });
  review.addEventListener('close', () => trigger.focus());
}
