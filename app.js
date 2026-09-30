const navItems = document.querySelectorAll('.nav-item');
const views = document.querySelectorAll('.view');
const pageTitle = document.querySelector('#page-title');
const titles = { overview: 'A day with a little more making.', classify: 'Tune the balance to you.', settings: 'Make it work your way.' };

function showView(name) {
  navItems.forEach((item) => item.classList.toggle('active', item.dataset.view === name));
  views.forEach((view) => view.classList.toggle('active-view', view.id === `view-${name}`));
  pageTitle.textContent = titles[name];
}

navItems.forEach((item) => item.addEventListener('click', () => showView(item.dataset.view)));
document.querySelectorAll('[data-view-link]').forEach((link) => link.addEventListener('click', () => showView(link.dataset.viewLink)));

const slider = document.querySelector('#limit-slider');
const limitValue = document.querySelector('#limit-value');
slider.addEventListener('input', (event) => {
  const value = event.target.value;
  limitValue.textContent = `${value}%`;
  document.querySelector('.limit-marker').style.left = `${value}%`;
  document.querySelector('.balance-state small').textContent = `Your ${value}% limit is safe`;
});

document.querySelectorAll('.toggle').forEach((toggle) => toggle.addEventListener('click', () => toggle.classList.toggle('on')));
document.querySelectorAll('.remove').forEach((button) => button.addEventListener('click', () => button.closest('.class-app').remove()));

document.querySelectorAll('.add-button').forEach((button) => button.addEventListener('click', () => {
  const appName = window.prompt('Which app should be added?');
  if (!appName) return;
  const row = document.createElement('div');
  row.className = 'class-app';
  row.innerHTML = `<span class="app-icon notion">•</span><span>${appName}</span><button class="remove">−</button>`;
  row.querySelector('.remove').addEventListener('click', () => row.remove());
  button.previousElementSibling.appendChild(row);
}));
