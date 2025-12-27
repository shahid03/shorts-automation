require('dotenv').config();
console.log('LLM_PROVIDER:', process.env.LLM_PROVIDER);
console.log('LLM_BASE_URL:', process.env.LLM_BASE_URL);
console.log('LLM_MODEL:', process.env.LLM_MODEL);
console.log('LLM_API_KEY:', process.env.LLM_API_KEY ? 'Set' : 'Not Set');
